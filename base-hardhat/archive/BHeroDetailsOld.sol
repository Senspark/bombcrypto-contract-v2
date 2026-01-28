// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library BHeroDetails {
  uint256 public constant ALL_RARITY = 0;
  uint256 public constant ALL_SKIN = 0;

  struct Details {
    uint256 id;
    uint256 index;
    uint256 rarity;
    uint256 level;
    uint256 color;
    uint256 skin;
    uint256 stamina;
    uint256 speed;
    uint256 bombSkin;
    uint256 bombCount;
    uint256 bombPower;
    uint256 bombRange;
    uint256[] abilities;
    uint256 blockNumber;
    uint256 randomizeAbilityCounter;
    uint256[] abilityHeroS;
    uint256 numResetShield;
    uint256 numUpgradeShieldLevel;
  }

  function encode(Details memory details) internal pure returns (uint256) {
    uint256 value;
    value |= details.id;
    value |= details.index << 30;
    value |= details.rarity << 40;
    value |= details.level << 45;
    value |= details.color << 50;
    value |= details.skin << 55;
    value |= details.stamina << 60;
    value |= details.speed << 65;
    value |= details.bombSkin << 70;
    value |= details.bombCount << 75;
    value |= details.bombPower << 80;
    value |= details.bombRange << 85;
    value |= details.abilities.length << 90;
    for (uint256 i = 0; i < details.abilities.length; ++i) {
      value |= details.abilities[i] << (95 + i * 5);
    }
    value |= details.blockNumber << 145;
    value |= details.randomizeAbilityCounter << 175;

    value |= details.abilityHeroS.length << 180;
    for (uint256 j = 0; j < details.abilityHeroS.length; ++j) {
      value |= details.abilityHeroS[j] << (185 + j * 5);
    }
    value |= details.numUpgradeShieldLevel << 235;
    value |= details.numResetShield << 240;

    return value;
  }

  function decode(uint256 details) internal pure returns (Details memory result) {
    result.id = decodeId(details);
    result.index = decodeIndex(details);
    result.rarity = decodeRarity(details);
    result.level = decodeLevel(details);
    result.color = (details >> 50) & 31;
    result.skin = (details >> 55) & 31;
    result.stamina = (details >> 60) & 31;
    result.speed = (details >> 65) & 31;
    result.bombSkin = (details >> 70) & 31;
    result.bombCount = (details >> 75) & 31;
    result.bombPower = (details >> 80) & 31;
    result.bombRange = (details >> 85) & 31;
    uint256 ability = (details >> 90) & 31;
    result.abilities = new uint256[](ability);
    for (uint256 i = 0; i < ability; ++i) {
      result.abilities[i] = (details >> (95 + i * 5)) & 31;
    }
    result.blockNumber = decodeBlockNumber(details);
    result.randomizeAbilityCounter = decodeRandomizeAbilityCounter(details);

    uint256 abilitySizeHeroS = (details >> 180) & 31;
    result.abilityHeroS = new uint256[](abilitySizeHeroS);
    for (uint256 j = 0; j < abilitySizeHeroS; ++j) {
      result.abilityHeroS[j] = (details >> (185 + j * 5)) & 31;
    }
    result.numUpgradeShieldLevel = (details >> 235) & 31;
    result.numResetShield = (details >> 240) & (2**10 - 1);
  }

  function decodeId(uint256 details) internal pure returns (uint256) {
    return details & ((1 << 30) - 1);
  }

  function decodeIndex(uint256 details) internal pure returns (uint256) {
    return (details >> 30) & ((1 << 10) - 1);
  }

  function decodeRarity(uint256 details) internal pure returns (uint256) {
    return (details >> 40) & 31;
  }

  function decodeLevel(uint256 details) internal pure returns (uint256) {
    return (details >> 45) & 31;
  }

  function decodeBlockNumber(uint256 details) internal pure returns (uint256) {
    return (details >> 145) & ((1 << 30) - 1);
  }

  function decodeRandomizeAbilityCounter(uint256 details) internal pure returns (uint256) {
    return (details >> 175) & 31;
  }

  function increaseLevel(uint256 details) internal pure returns (uint256) {
    uint256 level = decodeLevel(details);
    details &= ~(uint256(31) << 45);
    details |= (level + 1) << 45;
    return details;
  }

  //using to burn heros and reset shield
  function decodeNumResetShield(uint256 details) internal pure returns (uint256) {
    return (details >> 240) & (2**10 - 1);
  }

  function decodeShieldLevel(uint256 details) internal pure returns (uint256) {
    return (details >> 235) & 31;
  }

  function increaseNumResetShield(uint256 details) internal pure returns (uint256) {
    uint256 numResetShield = decodeNumResetShield(details);
    details &= ~(uint256(2**10 - 1) << 240);
    details |= (numResetShield + 1) << 240;
    return details;
  }

  /**
   * default shield level blockchain is 0 - display level 1
   */
  function increaseShieldLevel(uint256 details) internal pure returns (uint256) {
    uint256 level = decodeShieldLevel(details);
    details &= ~(uint256(31) << 235);
    details |= (level + 1) << 235;
    return details;
  }

  function setShieldLevel(uint256 details, uint256 newLevel) internal pure returns (uint256) {
    details &= ~(uint256(31) << 235);
    details |= newLevel << 235;
    return details;
  }

  function increaseRandomizeAbilityCounter(uint256 details) internal pure returns (uint256) {
    uint256 value = decodeRandomizeAbilityCounter(details);
    if (value >= 31) {
      return details;
    }
    details &= ~(uint256(31) << 175);
    details |= (value + 1) << 175;
    return details;
  }

  function setId(uint256 details, uint256 id) internal pure returns (uint256) {
    details &= ~((uint256(1) << 30) - 1);
    details |= id;
    return details;
  }

  function setIndex(uint256 details, uint256 index) internal pure returns (uint256) {
    details &= ~(uint256(1023) << 30);
    details |= index << 30;
    return details;
  }

  function isHeroS(uint256 details) internal pure returns (bool) {
    uint256 length = (details >> 180) & 31;
    return length > 0;
  }
}