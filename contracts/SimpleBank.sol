pragma ton-solidity >=0.61.0;
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

struct ProcessingDeposit {
	uint128 value;
	address user;
}

contract SimpleBank is ISimpleBank, IAcceptTokensTransferCallback {
	uint128 public static nonce;
	address tokenRoot;
	address public tokenWallet;
	address owner;
	uint128 tokenBalance;
	uint128 freeTokenBalance;
	TvmCell public userDataCode;
	uint128 constant CONTRACT_MIN_BALANCE = 1 ton;
	uint128 constant USER_DATA_DEPLOY_VALUE = 0.2 ton;
	uint128 constant TOKEN_WALLET_DEPLOY_GRAMS_VALUE = 0.1 ton;
	uint128 constant TOKEN_WALLET_DEPLOY_VALUE = 0.5 ton;
	uint8 constant NOT_ROOT_WALLET = 101;
	uint8 constant NOT_OWNER = 102;
	uint8 constant NOT_USER_DATA = 103;
	uint8 constant BURN_AMOUNT_HIGHER_THAN_USER_BALANCE = 104;
	uint8 constant NOT_ENOGH_FREE_BALANCE = 105;
	uint8 constant ZERO_AMOUNT_INPUT = 107;
	mapping(address => ProcessingDeposit) pendingDeposit;

	constructor(
		address _tokenRoot,
		TvmCell _userDataCode,
		address _owner
	) public {
		tvm.accept();
		tokenRoot = _tokenRoot;
		userDataCode = _userDataCode;
		owner = _owner;
		ITokenRoot(tokenRoot).deployWallet{
			value: TOKEN_WALLET_DEPLOY_VALUE,
			callback: SimpleBank.receiveTokenWalletAddress
		}(address(this), TOKEN_WALLET_DEPLOY_GRAMS_VALUE);
	}

	modifier onlyOwner() {
		require(msg.sender == owner, NOT_OWNER);
		_;
	}
	modifier onlyUserData(address user) {
		require(getUserDataAddress(user) == msg.sender, NOT_USER_DATA);
		_;
	}

	function receiveTokenWalletAddress(address wallet) external virtual {
		tvm.rawReserve(_reserve(), 0);
		tokenWallet = wallet;
	}

	function _reserve() internal pure returns (uint128) {
		return
			math.max(address(this).balance - msg.value, CONTRACT_MIN_BALANCE);
	}

	function getDetails() external view responsible override returns (Details) {
		return
			{value: 0, bounce: false, flag: MsgFlag.REMAINING_GAS} Details(
				tokenRoot,
				tokenWallet,
				tokenBalance,
				owner
			);
	}

	function _buildInitData(address _user)
		internal
		view
		virtual
		returns (TvmCell)
	{
		return
			tvm.buildStateInit({
				contr: UserData,
				varInit: {
					simpleBank: address(this),
					user: _user,
					userDataCode: userDataCode
				},
				pubkey: 0,
				code: userDataCode
			});
	}

	function registerUser(address send_gas_to) external override {
		tvm.rawReserve(_reserve(), 0);
		deployUserData(msg.sender);
		send_gas_to.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function deployUserData(address user_data_owner)
		internal
		virtual
		returns (address)
	{
		return
			new UserData{
				stateInit: _buildInitData(user_data_owner),
				value: USER_DATA_DEPLOY_VALUE
			}();
	}

	function getUserDataAddress(address user)
		public
		view
		virtual
		responsible
		returns (address)
	{
		return
			{value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} address(
				tvm.hash(_buildInitData(user))
			);
	}

	function finishDeposit(uint128 _amount, uint64 _nonce) external override {
		tvm.accept();
		address userData = msg.sender;
		emit Deposit(userData, _amount);
	}

	function withdraw(uint128 _amount, uint64 _nonce) external override {
		tvm.rawReserve(_reserve(), 0);
		require(_amount > 0, ZERO_AMOUNT_INPUT);
		address userDataAddr = getUserDataAddress(msg.sender);
		IUserData(userDataAddr).processWithdraw{
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(_amount, _nonce);
	}

	function finishWithdraw(
		address user,
		uint128 _amount,
		uint64 _nonce
	) external override onlyUserData(user) {
		TvmBuilder builder;
		builder.store(nonce);
		emit Withdraw(user, _amount);
		ITokenWallet(tokenWallet).transfer{
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED,
			bounce: true
		}(_amount, user, 0, user, false, builder.toCell());
	}

	function startBurn(address _targetUser, uint128 _amount)
		external
		override
		onlyOwner
	{
		tvm.rawReserve(_reserve(), 0);
		address targetUserData = getUserDataAddress(_targetUser);
		IUserData(targetUserData).burn{
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(_amount);
	}

	function finishBurn(uint128 _burnedAmount, address user)
		external
		override
		onlyUserData(user)
	{
		tvm.rawReserve(_reserve(), 0);
		freeTokenBalance += _burnedAmount;
		emit Burn(user, _burnedAmount);
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function sendToUser(address _targetUser, uint128 _amount)
		external
		override
		onlyOwner
	{
		require(_amount <= freeTokenBalance, NOT_ENOGH_FREE_BALANCE);
		tvm.rawReserve(_reserve(), 0);
		address userData = getUserDataAddress(_targetUser);
		pendingDeposit[userData] = ProcessingDeposit({
			value:_amount,
			user:_targetUser
		});
		IUserData(userData).receiveFromBank{
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(_amount);
	}

	function finishSendToUser(address _user) external override onlyUserData(_user) {
		tvm.rawReserve(_reserve(), 0);
		ProcessingDeposit deposit = pendingDeposit[msg.sender];
		emit Deposit(deposit.user, deposit.value);
		delete pendingDeposit[msg.sender];
        owner.transfer({ value: 0, bounce: false, flag: MsgFlag.ALL_NOT_RESERVED });
	}

	function handleSendToUserError(TvmSlice slice) internal {
		tvm.rawReserve(_reserve(), 0);
		ProcessingDeposit deposit = pendingDeposit[msg.sender];
		deployUserData(deposit.user);
		address userData = getUserDataAddress(deposit.user);
		IUserData(userData).receiveFromBank{
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(deposit.value);
	}

	function onAcceptTokensTransfer(
		address _tokenRoot,
		uint128 _amount,
		address _sender,
		address _senderWallet,
		address _remainingGasTo,
		TvmCell _payload
	) external virtual override {
		tvm.rawReserve(_reserve(), 0);
		require(msg.sender == tokenWallet, NOT_ROOT_WALLET);
		address userDataAddr = getUserDataAddress(_sender);
		IUserData(userDataAddr).processDeposit{
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(_amount, uint64(_amount));
	}

	onBounce(TvmSlice slice) external {
		tvm.accept();
		uint32 functionId = slice.decode(uint32);
		if (functionId == tvm.functionId(UserData.receiveFromBank)) {
			handleSendToUserError(slice);
		}
	}
}
