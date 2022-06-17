pragma ton-solidity >= 0.61.0;

import "./interfaces/~IUserData.sol";
import "./interfaces/~ISimpleBank.sol";
import "./~UserData.sol";
import "o:/projects/broxus/simple-bank/node_modules/@broxus/contracts/contracts/platform/Platform.sol";
import "o:/projects/broxus/simple-bank/node_modules/@broxus/contracts/contracts/libraries/MsgFlag.sol";
import "o:/projects/broxus/simple-bank/node_modules/broxus-ton-tokens-contracts/contracts/interfaces/ITokenRoot.sol";
import "o:/projects/broxus/simple-bank/node_modules/broxus-ton-tokens-contracts/contracts/interfaces/ITokenWallet.sol";

import "o:/projects/broxus/simple-bank/node_modules/broxus-ton-tokens-contracts/contracts/interfaces/IAcceptTokensTransferCallback.sol";
import "o:/projects/broxus/simple-bank/node_modules/locklift/locklift/console.sol";



pragma AbiHeader expire;

contract SimpleBank is ISimpleBank, IAcceptTokensTransferCallback {
        uint128 public static nonce;
        address tokenRoot;
        address public tokenWallet;
        address owner;
        uint128 tokenBalance;
        TvmCell public userDataCode;
        uint64 randomNonce;
        uint128 constant CONTRACT_MIN_BALANCE = 1 ton;
        uint128 constant USER_DATA_DEPLOY_VALUE = 0.2 ton;
        uint128 constant TOKEN_WALLET_DEPLOY_GRAMS_VALUE = 0.1 ton;
        uint128 constant TOKEN_WALLET_DEPLOY_VALUE = 0.5 ton;


        uint8 constant NOT_ROOT_WALLET = 101;
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

    function finishDeposit(
        uint128 _amount,
        uint64 _nonce
    ) external override {
        tvm.accept();
        address userData = msg.sender;
        emit Deposit(userData, _amount);
    }


    function _buildInitData(address _user) internal virtual view returns (TvmCell) {
        return tvm.buildStateInit({
            contr: UserData,
            varInit: {
                simpleBank: address(this),
                user: _user
            },
            pubkey: 0,
            code: userDataCode
        });
    }
    function deployUserData(address user_data_owner) internal virtual returns (address) {
        return new UserData{
            stateInit: _buildInitData(user_data_owner),
            value: USER_DATA_DEPLOY_VALUE
        }();
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
        ITokenWallet(tokenWallet).transfer{value: 0, flag: MsgFlag.ALL_NOT_RESERVED }(
            _amount,
            user,
            0,
            user,
            false,
            builder.toCell()
        );
    }

    function registerUser() public returns (address)  {
        tvm.accept();
        return deployUserData(msg.sender);
    }

    function getUserDataAddress(address user) public virtual view responsible returns (address) {
        return { value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false } address(tvm.hash(_buildInitData(user)));
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
