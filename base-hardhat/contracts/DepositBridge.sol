// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./signatureV1Lib.sol";

// Cross-chain balance bridge. Deposit on chain X credits withdraw capacity on the OTHER
// chain (directional; no same-chain withdraw). Withdraw is MAX: the contract self-computes
// `amount = otherDeposited - withdrawn` from its own on-chain state, so the only number it
// must trust from the backend is `otherDeposited` (the deposited counter on the source
// chain, signer-read at confirmed depth). The user relays `withdraw(...)` themselves with
// a backend SIGNER_ROLE signature and pays the gas — the operator runs no relayer. Runs in
// parallel on each supported chain and pays out from that chain's own liquidity.
contract DepositBridge is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
  bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
  bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");

  mapping(address => bool) public supportedToken;
  mapping(address => mapping(address => uint256)) public deposited;
  mapping(address => mapping(address => uint256)) public withdrawn; // chases otherDeposited
  mapping(address => uint256) public collectedFees;

  // Global counters for the monitor's per-chain solvency invariant:
  // tokenBalance == totalDeposited - totalWithdrawn + (SumFees - sweptFees) + totalFunded
  mapping(address => uint256) public totalDeposited;
  mapping(address => uint256) public totalWithdrawn;
  mapping(address => uint256) public totalFunded;
  mapping(address => uint256) public sweptFees;

  uint256 public feePercent; // whole percent

  // On-chain start/stop (appended at end of storage — UUPS-safe).
  // On an upgrade of an existing proxy both default false (fail-safe OFF); the operator
  // must setDepositEnabled(true)/setWithdrawEnabled(true) to open each direction.
  bool public depositEnabled;
  bool public withdrawEnabled;

  event Deposit(address indexed user, address indexed token, uint256 amount, uint256 depositedTotal);
  event Withdraw(
    address indexed user,
    address indexed token,
    uint256 amount,
    uint256 net,
    uint256 otherDeposited,
    uint256 deadline,
    uint256 withdrawnTotal
  );
  event LiquidityFunded(address indexed token, address indexed from, uint256 amount);
  event FeesSwept(address indexed token, address indexed to, uint256 amount);
  event FeePercentChanged(uint256 feePercent);
  event SupportedTokenChanged(address indexed token, bool supported);
  event DepositEnabledChanged(bool enabled);
  event WithdrawEnabledChanged(bool enabled);

  function initialize() public initializer {
    __AccessControl_init();
    __UUPSUpgradeable_init();

    feePercent = 5;

    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(UPGRADER_ROLE, msg.sender);
    _grantRole(MANAGER_ROLE, msg.sender);
    _grantRole(SIGNER_ROLE, msg.sender);
    _grantRole(WITHDRAWER_ROLE, msg.sender);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(AccessControlUpgradeable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  // --- User flows ---

  function deposit(address token, uint256 amount) external {
    require(supportedToken[token], "Token not supported");
    require(depositEnabled, "Deposit disabled");
    require(amount > 0, "Amount must be greater than 0");

    IERC20Upgradeable(token).safeTransferFrom(msg.sender, address(this), amount);

    deposited[msg.sender][token] += amount;
    totalDeposited[token] += amount;

    emit Deposit(msg.sender, token, amount, deposited[msg.sender][token]);
  }

  // User-relayed, withdraw-MAX. The backend (SIGNER_ROLE) signs, off-chain, the source-chain
  // deposited counter `otherDeposited` (read at confirmed depth) bound to this user + token +
  // deadline + this bridge. The contract self-computes the payable amount from its own state:
  //   amount = otherDeposited - withdrawn[user][token]
  // Replaying a signature yields amount = 0 → reject; a stale lower `otherDeposited` submitted
  // late underflows → revert; the server can never over-pay because it does not supply the
  // amount. `deadline` is just an operational window, not a safety gate.
  function withdraw(
    address token,
    uint256 otherDeposited,
    uint256 deadline,
    bytes memory signature
  ) external {
    require(supportedToken[token], "Token not supported");
    require(withdrawEnabled, "Withdraw disabled");
    require(block.timestamp <= deadline, "Expired");

    // Scoped so digest/signer free the stack before the payout math (avoids stack-too-deep
    // with the wide Withdraw event).
    {
      bytes32 digest = _hashWithdraw(msg.sender, token, otherDeposited, deadline);
      address signer = signtureERC721.checkMessageSignature(digest, signature);
      require(hasRole(SIGNER_ROLE, signer), "Bad signer");
    }

    uint256 amount = otherDeposited - withdrawn[msg.sender][token]; // underflow (0.8) reverts on a stale lower sig
    require(amount > 0, "Nothing to withdraw");

    uint256 net = (amount * (100 - feePercent)) / 100;

    withdrawn[msg.sender][token] += amount;
    totalWithdrawn[token] += amount;
    collectedFees[token] += amount - net;

    IERC20Upgradeable(token).safeTransfer(msg.sender, net);

    emit Withdraw(msg.sender, token, amount, net, otherDeposited, deadline, withdrawn[msg.sender][token]);
  }

  // --- Admin ---

  function setFeePercent(uint256 feePercent_) external onlyRole(MANAGER_ROLE) {
    require(feePercent_ < 100, "Fee must be less than 100");
    feePercent = feePercent_;
    emit FeePercentChanged(feePercent_);
  }

  function setSupportedToken(address token, bool supported) external onlyRole(MANAGER_ROLE) {
    supportedToken[token] = supported;
    emit SupportedTokenChanged(token, supported);
  }

  function setDepositEnabled(bool enabled) external onlyRole(MANAGER_ROLE) {
    depositEnabled = enabled;
    emit DepositEnabledChanged(enabled);
  }

  function setWithdrawEnabled(bool enabled) external onlyRole(MANAGER_ROLE) {
    withdrawEnabled = enabled;
    emit WithdrawEnabledChanged(enabled);
  }

  // Top up a chain's payout liquidity without crediting any user counter.
  // Permissionless: funding only adds tokens to the pool (never credits a user's
  // withdrawable balance), and both balanceOf and totalFunded move together so the
  // solvency invariant holds — so anyone may donate liquidity.
  function fundLiquidity(address token, uint256 amount) external {
    require(supportedToken[token], "Token not supported");
    require(amount > 0, "Amount must be greater than 0");

    IERC20Upgradeable(token).safeTransferFrom(msg.sender, address(this), amount);
    totalFunded[token] += amount;

    emit LiquidityFunded(token, msg.sender, amount);
  }

  function sweepFees(address token, address to) external onlyRole(WITHDRAWER_ROLE) {
    uint256 amount = collectedFees[token];
    require(amount > 0, "No fees to sweep");

    collectedFees[token] = 0;
    sweptFees[token] += amount;

    IERC20Upgradeable(token).safeTransfer(to, amount);

    emit FeesSwept(token, to, amount);
  }

  // --- Internal ---

  // EIP-191 digest the backend signs off-chain: [user, token, otherDeposited, deadline, address(this)].
  // `address(this)` binds the signature to this bridge proxy (domain separation across chains/proxies).
  function _hashWithdraw(
    address user,
    address token,
    uint256 otherDeposited,
    uint256 deadline
  ) private view returns (bytes32) {
    bytes32 rawMessage = keccak256(abi.encodePacked(user, token, otherDeposited, deadline, address(this)));
    return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", rawMessage));
  }
}
