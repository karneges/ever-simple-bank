pragma ton-solidity >= 0.61.0;
pragma AbiHeader expire;


interface ISimpleBank {
    event Deposit(address user, uint128 amount);
    event Withdraw(address user, uint128 amount);

    struct Details {
        address tokenRoot;
        address tokenWallet;
        uint128 tokenBalance;
        address owner;
    }

    function finishDeposit(
        uint128 _amount,
        uint64 _nonce
    ) external;

    function getDetails() external responsible view returns (Details);

    function withdraw(uint128 amount, uint64 nonce) external;

    function finishWithdraw(
        address user, uint128 _amount, uint64 _nonce
    ) external;
}
