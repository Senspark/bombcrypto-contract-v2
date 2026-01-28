// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBHouseDesign {
  function getTokenLimit() external view returns (uint256);

  function getMintLimits() external view returns (uint256[] memory);

  function getMintCost(uint256 rarity) external view returns (uint256);

  function createToken(uint256 id, uint256 rarity) external view returns (uint256 encodedDetails);
}
