pragma ton-solidity >= 0.61.0;
pragma AbiHeader expire;


interface IUserData {
    event UserDataUpdated(uint32 prev_version, uint32 new_version);

    struct UserDataDetails {
        uint128 amount;
        address user;
    }

    function getDetails() external responsible view returns (UserDataDetails);
    function processDeposit( uint128 _amount,uint64 nonce) external;
    function processWithdraw(uint128 _amount,uint64 nonce) external;
//    function processWithdraw(uint128 _amount, uint256[] _accTonPerShare, uint32 poolLastRewardTime, uint32 farmEndTime, address send_gas_to, uint32 nonce, uint32 code_version) external;
//    function processSafeWithdraw(address send_gas_to, uint32 code_version) external;
//    function processWithdrawAll(uint256[] _accTonShare, uint32 poolLastRewardTime, uint32 farmEndTime, address send_gas_to, uint32 nonce, uint32 code_version) external;
}
