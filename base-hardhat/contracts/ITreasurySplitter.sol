// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITreasurySplitter {
  // Source contracts with a fee ledger read this rather than storing their own copy.
  function usdtToken() external view returns (address);

  function distribute(
    address token,
    uint256 amount,
    address router,
    bytes calldata swapCalldata,
    uint256 minUsdtOut
  ) external returns (uint256 usdtOut);
}
