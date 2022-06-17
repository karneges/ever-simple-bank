pragma AbiHeader expire;

pragma ton-solidity >= 0.61.0;
import "./interfaces/~IUserData.sol";
import "./interfaces/~ISimpleBank.sol";
import "o:/projects/broxus/simple-bank/node_modules/@broxus/contracts/contracts/libraries/MsgFlag.sol";



contract UserData is IUserData {

    uint128 public amount;
    address static user;
    address static simpleBank;
    uint8 constant NOT_SIMPLE_BANK = 101;
    uint128 constant CONTRACT_MIN_BALANCE = 0.1 ton;



    constructor() public {  }

    function _reserve() internal pure returns (uint128) {
        return math.max(address(this).balance - msg.value, CONTRACT_MIN_BALANCE);
    }

    function getDetails() external responsible view override returns (UserDataDetails) {
        return { value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS }UserDataDetails(
            amount,  user
        );
    }

    function processDeposit(uint128 _amount,uint64 _nonce) external override {
        require(msg.sender == simpleBank, NOT_SIMPLE_BANK);
        tvm.rawReserve(_reserve(), 0);

        amount += _amount;
        ISimpleBank(msg.sender).finishDeposit{value: 0, flag: MsgFlag.ALL_NOT_RESERVED}(_amount,_nonce);
    }

    function processWithdraw(uint128 _amount,uint64 _nonce) external override {
        require(msg.sender == simpleBank, NOT_SIMPLE_BANK);
        tvm.rawReserve(_reserve(), 0);

        amount -= _amount;
        ISimpleBank(msg.sender).finishWithdraw{value: 0, flag: MsgFlag.ALL_NOT_RESERVED}(user, _amount,_nonce);
    }
}
