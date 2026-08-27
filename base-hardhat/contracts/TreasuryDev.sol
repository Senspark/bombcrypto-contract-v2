// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TreasuryBase.sol";

/// @title Holds the dev share and converts it to USDT on demand.
contract TreasuryDev is TreasuryBase {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  address public usdtToken;
  mapping(address => bool) public routerAllowed;
  bool private _swapping;

  event UsdtTokenChanged(address usdt);
  event RouterChanged(address indexed router, bool allowed);
  event FeesSwapped(address indexed tokenIn, uint256 amountIn, uint256 usdtOut, address indexed router);

  modifier nonReentrantSwap() {
    require(!_swapping, "Reentrant");
    _swapping = true;
    _;
    _swapping = false;
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

  // swapCalldata is built off-chain and must name this contract as the recipient.
  function swapToUSDT(
    address tokenIn,
    uint256 amountIn,
    address router,
    bytes calldata swapCalldata,
    uint256 minUsdtOut
  ) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrantSwap returns (uint256 usdtOut) {
    address usdt = usdtToken;
    require(usdt != address(0), "USDT not set");
    require(tokenIn != usdt, "tokenIn is USDT");
    require(routerAllowed[router], "Router not allowed");
    require(amountIn > 0, "amountIn=0");

    uint256 inBefore = IERC20Upgradeable(tokenIn).balanceOf(address(this));
    require(amountIn <= inBefore, "Exceeds balance");
    uint256 usdtBefore = IERC20Upgradeable(usdt).balanceOf(address(this));

    IERC20Upgradeable(tokenIn).forceApprove(router, amountIn);
    (bool ok, ) = router.call(swapCalldata);
    require(ok, "Swap failed");
    IERC20Upgradeable(tokenIn).forceApprove(router, 0);

    uint256 spent = inBefore - IERC20Upgradeable(tokenIn).balanceOf(address(this));
    require(spent <= amountIn, "Overspent");

    usdtOut = IERC20Upgradeable(usdt).balanceOf(address(this)) - usdtBefore;
    require(usdtOut >= minUsdtOut, "Insufficient USDT out");

    emit FeesSwapped(tokenIn, spent, usdtOut, router);
  }
}
