// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "./BHeroDetails.sol";
import "./IBHeroDesign.sol";
import "./Utils.sol";

contract BHeroDesign is AccessControlUpgradeable, UUPSUpgradeable, IBHeroDesign {
  struct StatsRange {
    uint256 min;
    uint256 max;
  }

  struct Stats {
    StatsRange stamina;
    StatsRange speed;
    uint256 bombCount;
    StatsRange bombPower;
    uint256 bombRange;
    uint256 ability;
  }

  struct AbilityDesign {
    uint256 minCost;
    uint256 maxCost;
    uint256 incrementalCost;
  }

  using BHeroDetails for BHeroDetails.Details;

  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  bytes32 public constant DESIGNER_ROLE = keccak256("DESIGNER_ROLE");

  uint256 private constant COLOR_COUNT = 5;
  uint256 private constant BOMB_SKIN_COUNT = 20;

  // Mapping from rarity to stats.
  mapping(uint256 => Stats) private rarityStats;

  uint256[] private abilityIds;
  uint256 private tokenLimit;
  uint256[] private dropRate;
  uint256 private mintCost;
  uint256 private maxLevel;
  uint256[][] private upgradeCosts;
  uint256[] private abilityRate;
  AbilityDesign[] private abilityDesigns;
  uint256 private skinCount;
  uint256[] private superBoxDropRate;
  uint256 private superBoxMintCost;
  uint256 private senMintCost;
  uint256 private mintCostHeroS;
  uint256 private senMintCostHeroS;
  //using in HeroS
  uint256[] private dropRateHeroS;
  uint256 private constant maskLast8Bits = uint256(0xff);
  uint256 private constant maskFirst248Bits = ~uint256(0xff);
  //number rock need to upgrade shield level
  uint256[][6] private numRockUpgradeShieldLevel;
  //all skins
  uint256[] private skinArr;

  function initialize() public initializer {
    __AccessControl_init();
    __UUPSUpgradeable_init();

    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(UPGRADER_ROLE, msg.sender);
    _setupRole(DESIGNER_ROLE, msg.sender);

    rarityStats[0] = Stats(
      StatsRange(1, 3), //
      StatsRange(1, 3),
      1,
      StatsRange(1, 3),
      1,
      1
    );
    rarityStats[1] = Stats(
      StatsRange(3, 6), //
      StatsRange(3, 6),
      2,
      StatsRange(3, 6),
      2,
      2
    );
    rarityStats[2] = Stats(
      StatsRange(6, 9), //
      StatsRange(6, 9),
      3,
      StatsRange(6, 9),
      3,
      3
    );
    rarityStats[3] = Stats(
      StatsRange(9, 12), //
      StatsRange(9, 12),
      4,
      StatsRange(9, 12),
      4,
      4
    );
    rarityStats[4] = Stats(
      StatsRange(12, 15), //
      StatsRange(12, 15),
      5,
      StatsRange(12, 15),
      5,
      5
    );
    rarityStats[5] = Stats(
      StatsRange(15, 18), //
      StatsRange(15, 18),
      6,
      StatsRange(15, 18),
      6,
      6
    );
    abilityIds = [1, 2, 3, 4, 5, 6, 7];
    abilityRate = [1, 2, 1, 1, 1, 2, 2];
    tokenLimit = 500;
    dropRate = [8287, 1036, 518, 104, 52, 4];
    mintCost = 10 ether;
    senMintCost = 5 ether;
    maxLevel = 5;
    upgradeCosts.push([1 ether, 2 ether, 4 ether, 7 ether]);
    upgradeCosts.push([2 ether, 4 ether, 5 ether, 9 ether]);
    upgradeCosts.push([2 ether, 4 ether, 5 ether, 10 ether]);
    upgradeCosts.push([3 ether, 7 ether, 11 ether, 22 ether]);
    upgradeCosts.push([7 ether, 18 ether, 40 ether, 146 ether]);
    upgradeCosts.push([9 ether, 25 ether, 56 ether, 199 ether]);
    abilityDesigns.push(AbilityDesign(2 ether, 2 ether, 0 ether));
    abilityDesigns.push(AbilityDesign(5 ether, 10 ether, 1 ether));
    abilityDesigns.push(AbilityDesign(10 ether, 20 ether, 2 ether));
    abilityDesigns.push(AbilityDesign(20 ether, 40 ether, 4 ether));
    abilityDesigns.push(AbilityDesign(35 ether, 60 ether, 5 ether));
    abilityDesigns.push(AbilityDesign(50 ether, 80 ether, 6 ether));
    skinCount = 10;
    superBoxDropRate = [8424, 1036, 418, 51, 21, 50];
    superBoxMintCost = 50 ether;
    mintCostHeroS = 45 ether;
    senMintCostHeroS = 10 ether;
    dropRateHeroS = [8287, 1036, 518, 104, 52, 4];
    //default apply HeroS
    numRockUpgradeShieldLevel[0] = [0, 0, 0, 0, 0, 0];
    numRockUpgradeShieldLevel[1] = [1, 2, 4, 6, 8, 10];
    numRockUpgradeShieldLevel[2] = [1, 2, 4, 6, 8, 10];
    numRockUpgradeShieldLevel[3] = [1, 2, 4, 6, 8, 10];
    //skin value
    skinArr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 14, 15, 16];
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

  /** Sets the drop rate. */
  function setDropRate(uint256[] memory value) external onlyRole(DESIGNER_ROLE) {
    dropRate = value;
  }

  function setDropRateHeroS(uint256[] memory value) external onlyRole(DESIGNER_ROLE) {
    dropRateHeroS = value;
  }

  function setSuperBoxDropRate(uint256[] memory value) external onlyRole(DESIGNER_ROLE) {
    superBoxDropRate = value;
  }

  /** Sets the minting fee. */
  function setMintCost(uint256 value) external onlyRole(DESIGNER_ROLE) {
    mintCost = value;
  }

  function setSenMintCost(uint256 value) external onlyRole(DESIGNER_ROLE) {
    senMintCost = value;
  }

  function setMintCostHeroS(uint256 value) external onlyRole(DESIGNER_ROLE) {
    mintCostHeroS = value;
  }

  function setSenMintCostHeroS(uint256 value) external onlyRole(DESIGNER_ROLE) {
    senMintCostHeroS = value;
  }

  function setSuperBoxMintCost(uint256 value) external onlyRole(DESIGNER_ROLE) {
    superBoxMintCost = value;
  }

  /** Sets max upgrade level. */
  function setMaxLevel(uint256 value) external onlyRole(DESIGNER_ROLE) {
    maxLevel = value;
  }

  /** Sets the current upgrade cost. */
  function setUpgradeCosts(uint256[][] memory value) external onlyRole(DESIGNER_ROLE) {
    upgradeCosts = value;
  }

  function setAbilityRate(uint256[] memory value) external onlyRole(DESIGNER_ROLE) {
    abilityRate = value;
  }

  function setRandomizeAbilityCost(
    uint256 rarity,
    uint256 minCost,
    uint256 maxCost,
    uint256 incrementalCost
  ) external onlyRole(DESIGNER_ROLE) {
    if (abilityDesigns.length > rarity) {
      AbilityDesign storage design = abilityDesigns[rarity];
      design.minCost = minCost;
      design.maxCost = maxCost;
      design.incrementalCost = incrementalCost;
    } else {
      require(abilityDesigns.length == rarity, "Invalid rarity");
      abilityDesigns.push(AbilityDesign(minCost, maxCost, incrementalCost));
    }
  }

  function setSkinVal(uint256[] memory value) external onlyRole(DESIGNER_ROLE) {
    skinArr = value;
  }

  /**
   * Change number rocks need to upgrade shield level
   * level default is 0 => show level 1
   * value is array number rocks needed
   */
  function setNumRockUpgradeShieldLevel(uint256 level, uint256[6] memory value) external onlyRole(DESIGNER_ROLE) {
    numRockUpgradeShieldLevel[level] = value;
  }

  function getRarityStats() external view returns (Stats[] memory) {
    uint256 size = dropRate.length;
    Stats[] memory result = new Stats[](size);
    for (uint256 i = 0; i < size; ++i) {
      result[i] = rarityStats[i];
    }
    return result;
  }

  function getTokenLimit() external view override returns (uint256) {
    return tokenLimit;
  }

  function getDropRate() external view override returns (uint256[] memory) {
    return dropRate;
  }

  function getSuperBoxDropRate() external view returns (uint256[] memory) {
    return superBoxDropRate;
  }

  function getMintCost() external view override returns (uint256) {
    return mintCost;
  }

  function getSenMintCost() external view override returns (uint256) {
    return senMintCost;
  }

  function getSuperBoxMintCost() external view override returns (uint256) {
    return superBoxMintCost;
  }

  function getMintCostHeroS() external view override returns (uint256) {
    return mintCostHeroS;
  }

  function getSenMintCostHeroS() external view override returns (uint256) {
    return senMintCostHeroS;
  }
  
  function getDropRateHeroS() external view override returns (uint256[] memory) {
    return dropRateHeroS;
  }

  function getMaxLevel() external view override returns (uint256) {
    return maxLevel;
  }

  function getUpgradeCost(uint256 rarity, uint256 level) external view override returns (uint256) {
    return upgradeCosts[rarity][level];
  }

  function getUpgradeCosts() external view returns (uint256[][] memory) {
    return upgradeCosts;
  }

  function getAbilityRate() external view returns (uint256[] memory) {
    return abilityRate;
  }

  function getRandomizeAbilityCost(uint256 rarity, uint256 times) external view override returns (uint256) {
    AbilityDesign storage design = abilityDesigns[rarity];
    uint256 cost = design.minCost + design.incrementalCost * times;
    return MathUpgradeable.min(cost, design.maxCost);
  }

  function getAbilityDesigns() external view returns (AbilityDesign[] memory) {
    return abilityDesigns;
  }

  function getRockUpgradeShieldLevel(uint256 rarity, uint256 level) external view override returns (uint256) {
    return numRockUpgradeShieldLevel[level][rarity];
  }

  function createTokens(
    uint256 tokenId,
    uint256 count,
    uint256 details
  ) external view override returns (uint256[] memory tokenDetails) {
    tokenDetails = new uint256[](count);
    uint256 rarity;
    uint256 targetBlock = details & ((1 << 30) - 1);
    uint256 dropLength = (details >> 40) & 31;
    uint256[] memory dropRateOption = new uint256[](dropLength);
    for (uint256 j = 0; j < dropLength; ++j) {
      dropRateOption[j] = (details >> (45 + j * 15)) & (2**15 - 1);
    }
    require(block.number > targetBlock, "Target block not arrived");
    uint256 seed = uint256(blockhash(targetBlock));
    if (seed == 0) {
      if (rarity == BHeroDetails.ALL_RARITY) {
        // Expired, forced common.
        if (dropLength > 0) {
          for (uint256 k = 0; k < dropLength; ++k) {
            if (dropRateOption[k] > 0) {
              rarity = k + 1;
              break;
            }
          }
        } else {
          // apply hero request before
          rarity = 1;
        }
      }

      // Re-roll seed.
      targetBlock = (block.number & maskFirst248Bits) + (targetBlock & maskLast8Bits);
      if (targetBlock >= block.number) {
        targetBlock -= 256;
      }
      seed = uint256(blockhash(targetBlock));
    }

    for (uint256 i = 0; i < count; ++i) {
      uint256 id = tokenId + i;
      uint256 tokenSeed = uint256(keccak256(abi.encode(seed, id)));
      uint256 detailResult;
      (, detailResult) = createRandomToken(tokenSeed, id, rarity, details, dropRateOption);
      tokenDetails[i] = detailResult;
    }
  }

  function createRandomToken(
    uint256 seedVal,
    uint256 id,
    uint256 rarity,
    uint256 detailsVal,
    uint256[] memory dropRateOption
  ) internal view returns (uint256 nextSeed, uint256 encodedDetails) {
    BHeroDetails.Details memory details;
    details.id = id;

    //fix: Stack too deep
    uint256 seed =seedVal;
    uint256 category = (detailsVal >> 30) & 31;
    bool isHeroS = ((detailsVal >> 35) & 1) == 1;
    uint256 skin = (detailsVal >> 135) & (2**5 - 1);

    bool isFusion = category == 3;
    bool isSuperBox = category == 1;

    if (isHeroS) {
      // Exclusive abilities for hero S.
      uint256[] memory abilityArr = new uint256[](1);
      abilityArr[0] = 1;
      details.abilityHeroS = abilityArr;
    }

    if (rarity == BHeroDetails.ALL_RARITY) {
      //random normal Hero and Super Hero
      (seed, details.rarity) = Utils.weightedRandom(
        seed,
        isSuperBox ? superBoxDropRate : dropRateOption.length > 0 ? dropRateOption : dropRate
      );
    } else {
      // Specified rarity.
      details.rarity = rarity - 1;
    }

    //check fusion action
    if (isFusion) {
      uint256 rarityTarget;
      uint256 maxVal;
      for (uint256 i = 0; i < dropRateOption.length; i++) {
        if (maxVal < dropRateOption[i]) {
          maxVal = dropRateOption[i];
          rarityTarget = i;
        }
      }

      //fusion failed
      if (rarityTarget != details.rarity) {
        return (seed, 0);
      }
    }

    details.level = 1;

    Stats storage stats = rarityStats[details.rarity];
    details.bombCount = stats.bombCount;
    details.bombRange = stats.bombRange;

    (seed, details.color) = Utils.randomRangeInclusive(seed, 1, COLOR_COUNT);
    if (skin == BHeroDetails.ALL_SKIN) {
      //except all event skill
      uint256 indexArr;
      uint256 lengthArr = skinArr.length - 1;
      uint256 seedSkin = seed;
      (seed, indexArr) = Utils.randomRangeInclusive(seedSkin, 0, lengthArr);
      details.skin = skinArr[indexArr];
    } else {
      details.skin = skin; // Start from one.
    }
    (seed, details.stamina) = Utils.randomRangeInclusive(seed, stats.stamina.min, stats.stamina.max);
    (seed, details.speed) = Utils.randomRangeInclusive(seed, stats.speed.min, stats.speed.max);
    (seed, details.bombSkin) = Utils.randomRangeInclusive(seed, 1, BOMB_SKIN_COUNT);
    (seed, details.bombPower) = Utils.randomRangeInclusive(seed, stats.bombPower.min, stats.bombPower.max);
    (seed, details.abilities) = generateAbilities(seed, details.rarity);
    details.blockNumber = block.number;

    nextSeed = seed;
    encodedDetails = details.encode();
  }

  function randomizeAbilities(uint256 seed, uint256 _details)
    external
    view
    override
    returns (uint256 nextSeed, uint256 encodedDetails)
  {
    BHeroDetails.Details memory details = BHeroDetails.decode(_details);
    (seed, details.abilities) = generateAbilities(seed, details.rarity);
    nextSeed = seed;
    encodedDetails = details.encode();
  }

  function generateAbilities(uint256 seed, uint256 rarity)
    internal
    view
    returns (uint256 nextSeed, uint256[] memory abilities)
  {
    uint256[] memory rate = abilityRate;
    if (rarity == 0) {
      // Common, ignore piercing block skill.
      rate[2] = 0;
    }
    Stats storage stats = rarityStats[rarity];
    (seed, abilities) = Utils.weightedRandomSampling(seed, abilityIds, rate, stats.ability);
    nextSeed = seed;
  }

  function dummyDeploy() public view returns (uint256) {
    return 0;
  }

}
