pragma ton-solidity >= 0.61.0;
pragma AbiHeader expire;
import "./IUserData.sol";



interface ISimpleBank {
    event Deposit(address user, uint128 amount);
    event Withdraw(address user, uint128 amount);
    event Burn(address user,uint128 amount);

    struct Details {
        address tokenRoot;
        address tokenWallet;
        uint128 tokenBalance;
        address owner;
    }

    function registerUser(address send_gas_to) external;
    function finishDeposit(
        uint128 _amount,
        uint64 _nonce
    ) external;
    function getDetails() external responsible view returns (Details);
    function withdraw(uint128 amount, uint64 nonce) external;
    function finishWithdraw(
        address user, uint128 _amount, uint64 _nonce
    ) external;
    function startBurn(address _targetUser,uint128 _amount) external;
    function finishBurn(uint128 _burnedAmount, address user) external;
    function sendToUser(address _targetuser,uint128 _amount) external;
    function finishSendToUser(address _user) external;
}
