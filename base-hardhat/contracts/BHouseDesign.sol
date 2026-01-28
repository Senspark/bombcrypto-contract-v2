// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./BHouseDetails.sol";
import "./IBHouseDesign.sol";

contract BHouseDesign is AccessControlUpgradeable, UUPSUpgradeable, IBHouseDesign {
  struct Stats {
    uint256 recovery;
    uint256 capacity;
  }

  using BHouseDetails for BHouseDetails.Details;

  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  bytes32 public constant DESIGNER_ROLE = keccak256("DESIGNER_ROLE");

  uint256 private constant COLOR_COUNT = 5;
  uint256 private constant SKIN_COUNT = 5;
  uint256 private constant BOMB_SKIN_COUNT = 20;

  // Mapping from rarity to stats.
  mapping(uint256 => Stats) private rarityStats;

  uint256 private tokenLimit;
  uint256[] private mintLimits;
  uint256[] private mintCosts;

  function initialize() public initializer {
    __AccessControl_init();
    __UUPSUpgradeable_init();

    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(UPGRADER_ROLE, msg.sender);
    _setupRole(DESIGNER_ROLE, msg.sender);

    rarityStats[0] = Stats(120, 4);
    rarityStats[1] = Stats(300, 6);
    rarityStats[2] = Stats(480, 8);
    rarityStats[3] = Stats(660, 10);
    rarityStats[4] = Stats(840, 12);
    rarityStats[5] = Stats(1020, 14);
    tokenLimit = 5;
    mintLimits = [2500, 1250, 750, 250, 200, 50];
    mintCosts = [
      720 ether, //
      2400 ether,
      5400 ether,
      9600 ether,
      15000 ether,
      21600 ether
    ];
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

  function supportsInterface(bytes4 interfaceId) public view override(AccessControlUpgradeable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  /** Sets the rarity stats. */
  function setRarityStats(uint256 rarity, Stats memory stats) external onlyRole(DESIGNER_ROLE) {
    rarityStats[rarity] = stats;
  }

  /** Sets the token limit. */
  function setTokenLimit(uint256 value) external onlyRole(DESIGNER_ROLE) {
    tokenLimit = value;
  }

  /** Sets the minting limits. */
  function setMintLimits(uint256[] memory value) external onlyRole(DESIGNER_ROLE) {
    mintLimits = value;
  }

  /** Sets the minting fee. */
  function setMintCosts(uint256[] memory value) external onlyRole(DESIGNER_ROLE) {
    mintCosts = value;
  }

  function getRarityStats() external view returns (Stats[] memory) {
    uint256 size = mintLimits.length;
    Stats[] memory result = new Stats[](size);
    for (uint256 i = 0; i < size; ++i) {
      result[i] = rarityStats[i];
    }
    return result;
  }

  function getTokenLimit() external view override returns (uint256) {
    return tokenLimit;
  }

  function getMintLimits() external view override returns (uint256[] memory) {
    return mintLimits;
  }

  function getMintCost(uint256 rarity) external view override returns (uint256) {
    return mintCosts[rarity];
  }

  function getMintCosts() external view returns (uint256[] memory) {
    return mintCosts;
  }

  function createToken(uint256 id, uint256 rarity) external view override returns (uint256 encodedDetails) {
    BHouseDetails.Details memory details;
    details.id = id;
    details.rarity = rarity;

    Stats storage stats = rarityStats[rarity];
    details.recovery = stats.recovery;
    details.capacity = stats.capacity;
    details.blockNumber = block.number;

    encodedDetails = details.encode();
  }
}
