pragma ton-solidity >= 0.61.0;
pragma AbiHeader expire;

import "./interfaces/IUserData.sol";
import "./interfaces/ISimpleBank.sol";
import "./UserData.sol";
import "@broxus/contracts/contracts/platform/Platform.sol";
import "@broxus/contracts/contracts/libraries/MsgFlag.sol";
import "broxus-ton-tokens-contracts/contracts/interfaces/ITokenRoot.sol";
import "broxus-ton-tokens-contracts/contracts/interfaces/ITokenWallet.sol";

import "broxus-ton-tokens-contracts/contracts/interfaces/IAcceptTokensTransferCallback.sol";
import "locklift/locklift/console.sol";
import "broxus-ton-tokens-contracts/contracts/abstract/TokenWalletBase.sol";



struct ProcessingBurn {
    uint128 value;
    address user;
}
contract SimpleBank is ISimpleBank, IAcceptTokensTransferCallback {
        uint128 public static nonce;
        address tokenRoot;
        address public tokenWallet;
        address owner;
        uint128 tokenBalance;
        TvmCell public userDataCode;
        uint64 randomNonce;
        mapping (address=>ProcessingBurn) pendingBurn;
        uint128 constant CONTRACT_MIN_BALANCE = 1 ton;
        uint128 constant USER_DATA_DEPLOY_VALUE = 0.2 ton;
        uint128 constant TOKEN_WALLET_DEPLOY_GRAMS_VALUE = 0.1 ton;
        uint128 constant TOKEN_WALLET_DEPLOY_VALUE = 0.5 ton;
        uint8 constant NOT_ROOT_WALLET = 101;
        uint8 constant NOT_OWNER = 102;
        uint8 constant NOT_USER_DATA = 103;
        uint8 constant BURN_AMOUNT_HIGHER_THAN_USER_BALANCE = 103;
        uint8 constant ZERO_AMOUNT_INPUT = 107;

constructor(address _tokenRoot,TvmCell _userDataCode,uint64 _randomNonce) public {
        tvm.accept();
        tokenRoot = _tokenRoot;
        userDataCode = _userDataCode;
        randomNonce = _randomNonce;
        owner = msg.sender;
        ITokenRoot(tokenRoot).deployWallet{value: TOKEN_WALLET_DEPLOY_VALUE, callback: SimpleBank.receiveTokenWalletAddress }(
            address(this),
            TOKEN_WALLET_DEPLOY_GRAMS_VALUE
        );
    }

    function receiveTokenWalletAddress(
        address wallet
    ) external virtual {
        tvm.rawReserve(_reserve(), 0);
        tokenWallet = wallet;
    }

    function _reserve() internal pure returns (uint128) {
        return math.max(address(this).balance - msg.value, CONTRACT_MIN_BALANCE);
    }

    function getDetails() external responsible view override returns (Details) {
        return { value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS }Details(
        tokenRoot,tokenWallet,tokenBalance,owner
        );
    }

    function _buildInitData(address _user) internal virtual view returns (TvmCell) {
        return tvm.buildStateInit({
            contr: UserData,
            varInit: {
                simpleBank: address(this),
                user: _user,
                userDataCode:userDataCode
            },
            pubkey: 0,
            code: userDataCode
        });
    }

    function registerUser(address send_gas_to) external override {
        tvm.rawReserve(_reserve(), 0);
        deployUserData(msg.sender);
        send_gas_to.transfer({ value: 0, bounce: false, flag: MsgFlag.ALL_NOT_RESERVED });
    }

    function deployUserData(address user_data_owner) internal virtual returns (address) {
        return new UserData{
            stateInit: _buildInitData(user_data_owner),
            value: USER_DATA_DEPLOY_VALUE
        }();
    }

    function getUserDataAddress(address user) public virtual view responsible returns (address) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } address(tvm.hash(_buildInitData(user)));
    }

    function finishDeposit(
        uint128 _amount,
        uint64 _nonce
    ) external override {
        tvm.accept();
        address userData = msg.sender;
        emit Deposit(userData, _amount);
    }

    function withdraw(uint128 _amount, uint64 _nonce) external override {
            tvm.rawReserve(_reserve(), 0);
            require (_amount > 0, ZERO_AMOUNT_INPUT);
            address userDataAddr = getUserDataAddress(msg.sender);
            IUserData(userDataAddr).processWithdraw{value: 0, flag: MsgFlag.ALL_NOT_RESERVED}(_amount, _nonce);
    }

    function finishWithdraw(address user, uint128 _amount,uint64 _nonce) external override  {
        TvmBuilder builder;
        builder.store(nonce);
        emit Withdraw(user, _amount);
        ITokenWallet(tokenWallet).transfer{value: 0, flag: MsgFlag.ALL_NOT_RESERVED,bounce:true }(
            _amount,
            user,
            0,
            user,
            false,
            builder.toCell()
        );
    }

    function startBurn(address _targetUser,uint128 _amount) external override {
        require(msg.sender == owner,NOT_OWNER);
        tvm.rawReserve(_reserve(), 0);
        address targetUserData = getUserDataAddress(_targetUser);
        pendingBurn[targetUserData] = ProcessingBurn({
            value:_amount,
            user:_targetUser
        });
        IUserData(targetUserData).getDetails{
            value: 0,
             callback: SimpleBank.finishBurn,
             flag: MsgFlag.ALL_NOT_RESERVED
             }();
    }

    function finishBurn(IUserData.UserDataDetails userData) external override {
        ProcessingBurn burnProcess = pendingBurn[msg.sender];
        require(burnProcess.user == userData.user, NOT_USER_DATA);
        tvm.rawReserve(_reserve(), 0);
        delete pendingBurn[msg.sender];
        require(burnProcess.value <= userData.amount, BURN_AMOUNT_HIGHER_THAN_USER_BALANCE);
        IUserData(msg.sender).burn{value:0,flag:MsgFlag.ALL_NOT_RESERVED}(burnProcess.value,burnProcess.user);
    }
    function dummy(address user_wallet) external virtual { tvm.rawReserve(_reserve(), 0); }

    onBounce(TvmSlice slice) external virtual {
        tvm.accept();
        console.log(format("Bounce! slice = {}", msg.sender));
        uint32 functionId = slice.decode(uint32);

        if (functionId == tvm.functionId(TokenWalletBase.transfer)) {

            tvm.rawReserve(_reserve(), 0);
           (uint128 amount,
            address recipient,
            uint128 deployWalletValue,
            address remainingGasTo,
            bool notify,
            TvmCell payload) = slice.decodeFunctionParams(TokenWalletBase.transfer);
            console.log(format("Bounce! amount = {}", amount));
            console.log(format("Bounce! recipient = {}", recipient));
            console.log(format("Bounce! deployWalletValue = {}", deployWalletValue));
            console.log(format("Bounce! remainingGasTo = {}", remainingGasTo));
            ITokenWallet(tokenRoot).transfer{value: TOKEN_WALLET_DEPLOY_VALUE }(
                amount,
                recipient,
                TOKEN_WALLET_DEPLOY_GRAMS_VALUE,
                remainingGasTo,
                notify,
                payload
            );
        }
    }


    function onAcceptTokensTransfer(
        address _tokenRoot,
        uint128 _amount,
        address _sender,
        address _senderWallet,
        address _remainingGasTo,
        TvmCell _payload
    ) external override virtual {
        tvm.rawReserve(_reserve(), 0);
        require(msg.sender == tokenWallet,NOT_ROOT_WALLET);
        address userDataAddr = getUserDataAddress(_sender);
        IUserData(userDataAddr).processDeposit{value:0,flag:MsgFlag.ALL_NOT_RESERVED}(_amount,uint64(_amount));
    }
}
