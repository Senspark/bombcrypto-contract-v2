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

  // --- Treasury fee-swap state (defaults zero/false on upgrade; manager must configure first) ---
  address public usdtToken;                          // swap output; the only token withdrawTreasuryUsdt moves
  mapping(address => bool) public swapRouterAllowed;  // whitelist of DEX routers swapFeesToUSDT may call
  bool private _swapping;                             // reentrancy latch (false on upgrade = unlocked)

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
  event TokensRescued(address indexed token, address indexed to, uint256 amount);
  event FeePercentChanged(uint256 feePercent);
  event SupportedTokenChanged(address indexed token, bool supported);
  event DepositEnabledChanged(bool enabled);
  event WithdrawEnabledChanged(bool enabled);
  event FeesSwapped(address indexed tokenIn, uint256 amountIn, uint256 usdtOut, address indexed router);
  event TreasuryUsdtWithdrawn(address indexed to, uint256 amount);

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

  // Liquidation escape hatch for retiring this proxy; not for routine ops (use sweepFees instead).
  function rescueTokens(address token, address to) external onlyRole(DEFAULT_ADMIN_ROLE) {
    uint256 bal = IERC20Upgradeable(token).balanceOf(address(this));
    require(bal > 0, "Nothing to rescue");

    IERC20Upgradeable(token).safeTransfer(to, bal);

    emit TokensRescued(token, to, bal);
  }

  // --- Treasury fee swap ---

  modifier nonReentrantSwap() {
    require(!_swapping, "Reentrant");
    _swapping = true;
    _;
    _swapping = false;
  }

  function setUsdtToken(address usdt) external onlyRole(MANAGER_ROLE) {
    require(usdt != address(0), "Zero address");
    usdtToken = usdt;
  }

  function setSwapRouter(address router, bool allowed) external onlyRole(MANAGER_ROLE) {
    require(router != address(0), "Zero address");
    swapRouterAllowed[router] = allowed;
  }

  // Convert accrued fees into USDT via a whitelisted router; route/calldata come from the manager's
  // off-chain UI. Approval is scoped to amountIn and reset after; balance deltas enforce spent <=
  // amountIn and usdtOut >= minUsdtOut so the quote isn't trusted blindly.
  function swapFeesToUSDT(
    address tokenIn,
    uint256 amountIn,
    address router,
    bytes calldata swapCalldata,
    uint256 minUsdtOut
  ) external onlyRole(MANAGER_ROLE) nonReentrantSwap {
    address usdt = usdtToken;
    require(usdt != address(0), "USDT not set");
    require(tokenIn != usdt, "tokenIn is USDT");
    require(swapRouterAllowed[router], "Router not allowed");
    require(amountIn > 0, "amountIn=0");
    require(amountIn <= collectedFees[tokenIn], "Exceeds collected fees");

    uint256 inBefore = IERC20Upgradeable(tokenIn).balanceOf(address(this));
    uint256 usdtBefore = IERC20Upgradeable(usdt).balanceOf(address(this));

    // Effects before interaction; reconciled below if the router underspends.
    collectedFees[tokenIn] -= amountIn;
    sweptFees[tokenIn] += amountIn;

    IERC20Upgradeable(tokenIn).forceApprove(router, amountIn);
    (bool ok, ) = router.call(swapCalldata);
    require(ok, "Swap failed");
    IERC20Upgradeable(tokenIn).forceApprove(router, 0);

    uint256 spent = inBefore - IERC20Upgradeable(tokenIn).balanceOf(address(this));
    require(spent <= amountIn, "Overspent");
    if (spent < amountIn) {
      uint256 refund = amountIn - spent;
      collectedFees[tokenIn] += refund;
      sweptFees[tokenIn] -= refund;
    }

    uint256 usdtOut = IERC20Upgradeable(usdt).balanceOf(address(this)) - usdtBefore;
    require(usdtOut >= minUsdtOut, "Insufficient USDT out");

    emit FeesSwapped(tokenIn, spent, usdtOut, router);
  }

  // USDT isn't a bridged token, so moving it never touches user liquidity accounting.
  function withdrawTreasuryUsdt(address to, uint256 amount) external onlyRole(MANAGER_ROLE) {
    address usdt = usdtToken;
    require(usdt != address(0), "USDT not set");
    require(to != address(0), "Zero address");
    require(amount > 0, "amount=0");

    IERC20Upgradeable(usdt).safeTransfer(to, amount);

    emit TreasuryUsdtWithdrawn(to, amount);
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
