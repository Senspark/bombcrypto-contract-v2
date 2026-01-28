// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./IBHeroDesign.sol";

interface IBHeroToken {
  function claimHero(uint256 _count, address _to) external;

  function createTokenRequest(
    address to,
    uint256 count,
    uint256 rarity,
    uint256 targetBlock,
    uint256 details
  ) external;

  function design() external view returns (IBHeroDesign);

  function getTotalHeroByUser(address user) external view returns (uint256);
}
