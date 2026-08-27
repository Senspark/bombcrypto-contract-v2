// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Utils {
  // State-transition function of the PRNG, not a source of entropy: consecutive draws from a
  // chained seed are independent. Deliberately pure.
  function randomSeed(uint256 seed) internal pure returns (uint256) {
    return uint256(keccak256(abi.encode(seed)));
  }

  /// Random [0, modulus)
  function random(uint256 seed, uint256 modulus) internal pure returns (uint256 nextSeed, uint256 result) {
    nextSeed = randomSeed(seed);
    result = nextSeed % modulus;
  }

  /// Random [from, to)
  function randomRange(
    uint256 seed,
    uint256 from,
    uint256 to
  ) internal pure returns (uint256 nextSeed, uint256 result) {
    require(from < to, "Invalid random range");
    (nextSeed, result) = random(seed, to - from);
    result += from;
  }

  /// Random [from, to]
  function randomRangeInclusive(
    uint256 seed,
    uint256 from,
    uint256 to
  ) internal pure returns (uint256 nextSeed, uint256 result) {
    return randomRange(seed, from, to + 1);
  }

  /// Weighted random.
  function weightedRandom(uint256 seed, uint256[] memory weights)
    internal
    pure
    returns (uint256 nextSeed, uint256 index)
  {
    require(weights.length > 0, "Array must not empty");
    uint256 totalWeight;
    for (uint256 i = 0; i < weights.length; ++i) {
      totalWeight += weights[i];
    }
    uint256 randMod;
    (seed, randMod) = randomRange(seed, 0, totalWeight);
    uint256 total;
    for (uint256 i = 0; i < weights.length; i++) {
      total += weights[i];
      if (randMod < total) {
        return (seed, i);
      }
    }
    return (seed, 0);
  }
}
