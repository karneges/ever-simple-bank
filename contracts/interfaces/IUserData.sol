pragma ton-solidity >= 0.61.0;
pragma AbiHeader expire;


interface IUserData {
    event Receive(address fromUser,uint128 amount);
    event Send(address toUser,uint128 amount);
    struct UserDataDetails {
        uint128 amount;
        address user;
    }

    function getDetails() external responsible view returns (UserDataDetails);
    function processDeposit( uint128 _amount,uint64 nonce) external;
    function processWithdraw(uint128 _amount,uint64 nonce) external;
    function sendToUser(address _targetUser,uint128 _amount,address send_gas_to) external;
    function receiveFromUser(address _user,uint128 _amount,address send_gas_to) external;
    function receiveFromBank(uint128 _amount) external;
    function burn(uint128 _amount) external;
//    function processWithdraw(uint128 _amount, uint256[] _accTonPerShare, uint32 poolLastRewardTime, uint32 farmEndTime, address send_gas_to, uint32 nonce, uint32 code_version) external;
//    function processSafeWithdraw(address send_gas_to, uint32 code_version) external;
//    function processWithdrawAll(uint256[] _accTonShare, uint32 poolLastRewardTime, uint32 farmEndTime, address send_gas_to, uint32 nonce, uint32 code_version) external;
}
