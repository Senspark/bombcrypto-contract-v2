// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./ITreasurySplitter.sol";

/// @title Splits a source contract's fee tokens four ways in one transaction.
/// One instance per chain. Holds tokens only mid-transaction, never at rest.
/// All four legs are plain transfers; the dev share is swapped to USDT in TreasuryDev.
contract TreasurySplitter is
  Initializable,
  AccessControlUpgradeable,
  ReentrancyGuardUpgradeable,
  UUPSUpgradeable,
  ITreasurySplitter
{
  using SafeERC20Upgradeable for IERC20Upgradeable;

  uint16 public constant BPS_DENOMINATOR = 10000;

  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

  address public communityTreasury;
  address public marketingTreasury;
  address public burnTreasury;
  address public override usdtToken;
  // Reserved; the swap moved to TreasuryDev.
  mapping(address => bool) public routerAllowed;

  struct Split {
    uint16 communityBps;
    uint16 devBps;
    uint16 marketingBps;
    uint16 burnBps;
    bool set;
  }

  // Keyed by the calling source contract, so one splitter serves every market/stake with its own ratios.
  mapping(address => Split) public splitOf;

  address public devTreasury;

  event TreasuriesChanged(address community, address marketing, address burn);
  event DevTreasuryChanged(address dev);
  event UsdtTokenChanged(address usdt);
  event RouterChanged(address indexed router, bool allowed);
  event SplitChanged(address indexed source, uint16 communityBps, uint16 devBps, uint16 marketingBps, uint16 burnBps);
  event DustSwept(address indexed token, address indexed receiver, uint256 amount);
  event Distributed(
    address indexed source,
    address indexed token,
    uint256 amount,
    uint256 community,
    uint256 dev,
    uint256 marketing,
    uint256 burn,
    uint256 usdtOut
  );

  function initialize() public initializer {
    __AccessControl_init();
    __ReentrancyGuard_init();
    __UUPSUpgradeable_init();

    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(UPGRADER_ROLE, msg.sender);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

  // --- config ---

  function setTreasuries(address community, address marketing, address burn) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(community != address(0) && marketing != address(0) && burn != address(0), "Zero address");
    communityTreasury = community;
    marketingTreasury = marketing;
    burnTreasury = burn;
    emit TreasuriesChanged(community, marketing, burn);
  }

  function setDevTreasury(address dev) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(dev != address(0), "Zero address");
    devTreasury = dev;
    emit DevTreasuryChanged(dev);
  }

  function setUsdtToken(address usdt) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(usdt != address(0), "Zero address");
    usdtToken = usdt;
    emit UsdtTokenChanged(usdt);
  }

  function setRouter(address router, bool allowed) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(router != address(0), "Zero address");
    routerAllowed[router] = allowed;
    emit RouterChanged(router, allowed);
  }

  function setSplit(
    address source,
    uint16 communityBps,
    uint16 devBps,
    uint16 marketingBps,
    uint16 burnBps
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(source != address(0), "Zero address");
    require(
      uint256(communityBps) + devBps + marketingBps + burnBps == BPS_DENOMINATOR,
      "Bps must sum to 10000"
    );
    splitOf[source] = Split(communityBps, devBps, marketingBps, burnBps, true);
    emit SplitChanged(source, communityBps, devBps, marketingBps, burnBps);
  }

  // Nothing should sit here between transactions; this is the exit for anything that does.
  function sweepDust(address token, address receiver, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(receiver != address(0), "Zero address");
    require(amount > 0, "Amount=0");
    IERC20Upgradeable(token).safeTransfer(receiver, amount);
    emit DustSwept(token, receiver, amount);
  }

  // --- distribution ---

  // router / swapCalldata / minUsdtOut are ignored; the dev share is swapped in TreasuryDev.
  function distribute(
    address token,
    uint256 amount,
    address /* router */,
    bytes calldata /* swapCalldata */,
    uint256 /* minUsdtOut */
  ) external override nonReentrant returns (uint256 usdtOut) {
    Split memory s = splitOf[msg.sender];
    require(s.set, "Source not configured");
    require(amount > 0, "amount=0");
    require(
      communityTreasury != address(0) && marketingTreasury != address(0) && burnTreasury != address(0),
      "Treasuries not set"
    );

    IERC20Upgradeable(token).safeTransferFrom(msg.sender, address(this), amount);

    uint256 community = (amount * s.communityBps) / BPS_DENOMINATOR;
    uint256 marketing = (amount * s.marketingBps) / BPS_DENOMINATOR;
    uint256 burn = (amount * s.burnBps) / BPS_DENOMINATOR;
    // Remainder, so rounding dust lands in the dev leg instead of being lost.
    uint256 dev = amount - community - marketing - burn;

    // Gated on devBps, not on dev.
    if (s.devBps > 0) {
      require(devTreasury != address(0), "Dev treasury not set");
      IERC20Upgradeable(token).safeTransfer(devTreasury, dev);
    } else if (dev > 0) {
      IERC20Upgradeable(token).safeTransfer(msg.sender, dev);
    }

    if (community > 0) IERC20Upgradeable(token).safeTransfer(communityTreasury, community);
    if (marketing > 0) IERC20Upgradeable(token).safeTransfer(marketingTreasury, marketing);
    if (burn > 0) IERC20Upgradeable(token).safeTransfer(burnTreasury, burn);

    emit Distributed(msg.sender, token, amount, community, dev, marketing, burn, usdtOut);
  }

  /*
  function _swapDevLeg(
    address token,
    uint256 dev,
    address router,
    bytes calldata swapCalldata,
    uint256 minUsdtOut
  ) private returns (uint256 usdtOut) {
    address source = msg.sender;
    address usdt = usdtToken;
    require(usdt != address(0), "USDT not set");
    require(token != usdt, "token is USDT");
    require(routerAllowed[router], "Router not allowed");

    uint256 tokenBefore = IERC20Upgradeable(token).balanceOf(address(this));
    uint256 usdtBefore = IERC20Upgradeable(usdt).balanceOf(source);

    IERC20Upgradeable(token).forceApprove(router, dev);
    (bool ok, ) = router.call(swapCalldata);
    require(ok, "Swap failed");
    IERC20Upgradeable(token).forceApprove(router, 0);

    uint256 spent = tokenBefore - IERC20Upgradeable(token).balanceOf(address(this));
    require(spent <= dev, "Overspent");

    usdtOut = IERC20Upgradeable(usdt).balanceOf(source) - usdtBefore;
    require(usdtOut >= minUsdtOut, "Insufficient USDT out");

    if (dev > spent) {
      IERC20Upgradeable(token).safeTransfer(source, dev - spent);
    }
  }
  */
}
