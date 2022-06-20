pragma AbiHeader expire;

pragma ton-solidity >= 0.61.0;
import "./interfaces/IUserData.sol";
import "./interfaces/ISimpleBank.sol";
import "@broxus/contracts/contracts/libraries/MsgFlag.sol";
import "locklift/locklift/console.sol";




contract UserData is IUserData {

    uint128 public amount;
    address static user;
    TvmCell public static userDataCode;
    address static simpleBank;
    uint8 constant NOT_SIMPLE_BANK = 101;
    uint8 constant NOT_USER_DATA = 102;
    uint8 constant ZERO_BALANCE = 102;
    uint128 constant CONTRACT_MIN_BALANCE = 0.1 ton;

    constructor() public {
        require(msg.sender == simpleBank, NOT_SIMPLE_BANK);
     }
    modifier onlyRoot() {
        require(msg.sender == simpleBank, NOT_SIMPLE_BANK);
        _;
    }
    modifier hasBalance() {
        require(amount > 0, ZERO_BALANCE);
        _;
    }
    function _buildInitData(address _user) internal view returns (TvmCell) {
        return tvm.buildStateInit({
            contr: UserData,
            varInit: {
                simpleBank: simpleBank,
                user: _user,
                userDataCode:userDataCode
            },
            pubkey: 0,
            code: userDataCode
        });
    }
    function _reserve() internal pure returns (uint128) {
        return math.max(address(this).balance - msg.value, CONTRACT_MIN_BALANCE);
    }

    function getDetails() external responsible view override returns (UserDataDetails) {
        return { value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS }UserDataDetails(
            amount,  user
        );
    }
    function increaseAmount(uint128 _amount) internal {
         amount += _amount;
    }
    function decreaseAmount(uint128 _amount) internal {
         amount -= _amount;
    }

    function processDeposit(uint128 _amount,uint64 _nonce) external override onlyRoot {
        tvm.rawReserve(_reserve(), 0);

        increaseAmount(_amount);
        ISimpleBank(msg.sender).finishDeposit{value: 0, flag: MsgFlag.ALL_NOT_RESERVED}(_amount,_nonce);
    }

    function burn(uint128 _amount) external override hasBalance onlyRoot {
        tvm.rawReserve(_reserve(), 0);
        uint128 amountToBurn = getAmountToBurn(_amount);
        decreaseAmount(amountToBurn);
        ISimpleBank(simpleBank).finishBurn{value:0,flag:MsgFlag.ALL_NOT_RESERVED}(amountToBurn,user);
    }

    function getAmountToBurn(uint128 _amount) internal returns (uint128) {
        if (_amount <= amount) {
            return _amount;
        } 
        return  amount;
    }
    
    function processWithdraw(uint128 _amount,uint64 _nonce) external override onlyRoot {
        tvm.rawReserve(_reserve(), 0);

        decreaseAmount(_amount);
        ISimpleBank(msg.sender).finishWithdraw{value: 0, flag: MsgFlag.ALL_NOT_RESERVED}(user, _amount,_nonce);
    }

    function sendToUser(address _targetUser,uint128 _amount,address send_gas_to) external override {
        tvm.rawReserve(_reserve(), 0);
        address targetUserAccount = address(tvm.hash(_buildInitData(_targetUser)));
        decreaseAmount(_amount);
        emit Send(_targetUser,_amount);
        IUserData(targetUserAccount).receiveFromUser{value: 0, flag: MsgFlag.ALL_NOT_RESERVED}(user,_amount,send_gas_to);
    }

    function receiveFromUser(address _user,uint128 _amount,address send_gas_to) external override {
        require(msg.sender == address(tvm.hash(_buildInitData(_user))),NOT_USER_DATA);
        tvm.rawReserve(_reserve(), 0);
        increaseAmount(_amount);
        emit Receive(_user,_amount);
        send_gas_to.transfer({ value: 0, bounce: false, flag: MsgFlag.ALL_NOT_RESERVED });
    }

    function receiveFromBank(uint128 _amount) external override onlyRoot {
        tvm.rawReserve(_reserve(), 0);
        increaseAmount(_amount);
        emit Receive(simpleBank,_amount);
        ISimpleBank(simpleBank).finishSendToUser{value: 0, flag: MsgFlag.ALL_NOT_RESERVED}(user);
    }
}
