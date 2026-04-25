// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBHeroDesign {
  function getTokenLimit() external view returns (uint256);

  function getBulkLimit(address user) external view returns (uint256);

  function getAccountLevel(address user) external view returns (uint256);

  function getMintDiscount(address user) external view returns (uint256);

  function incrementMintCount(address user, uint256 amount) external;

  function getMintCost(address user) external view returns (uint256);

  function getSenMintCost(address user) external view returns (uint256);

  function getSuperBoxMintCost(address user) external view returns (uint256);

  function getMaxLevel() external view returns (uint256);

  function getUpgradeCost(uint256 rarity, uint256 level) external view returns (uint256);

  function getRandomizeAbilityCost(uint256 rarity, uint256 times) external view returns (uint256);

  function getDropRate() external view returns (uint256[] memory);

  function getDropRateHeroS() external view returns (uint256[] memory);

  function getMintCostHeroS(address user) external view returns (uint256);

  function getSenMintCostHeroS(address user) external view returns (uint256);

  function getRockUpgradeShieldLevel(uint256 rarity, uint256 level) external view returns (uint256);

  function randomizeAbilities(uint256 seed, uint256 details)
    external
    view
    returns (uint256 nextSeed, uint256 encodedDetails);

  function createTokens(uint256 tokenId, uint256 count, uint256 details) external view returns (uint256[] memory tokenDetails);
}