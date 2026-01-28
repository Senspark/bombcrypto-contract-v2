// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library UtilsAT {
  function sort(address[] memory addresses, uint256[] memory balances) internal pure {
    uint256 size = addresses.length;
    require(size == balances.length, "Size not matched");
    for (uint256 i = 1; i < size; ++i) {
      uint256 key = balances[i];
      address addressKey = addresses[i];
      uint256 j = i;
      while (j > 0 && balances[j - 1] > key) {
        balances[j] = balances[j - 1];
        addresses[j] = addresses[j - 1];
        j = j - 1;
      }
      balances[j] = key;
      addresses[j] = addressKey;
    }
  }

  function distribute(uint256[] memory balances, uint256 amount) internal pure returns (uint256 target) {
    uint256 size = balances.length;
    require(size > 0, "Empty size");
    bool found = false;
    uint256 sum = 0;
    for (uint256 i = 0; i + 1 < size; ++i) {
      uint256 current = balances[i];
      uint256 next = balances[i + 1];
      uint256 total = (next - current) * (i + 1);
      if (sum + total > amount) {
        uint256 more = (amount - sum) / (i + 1);
        target = current + more;
        found = true;
        break;
      }
      sum += total;
    }
    if (!found) {
      // Surpass.
      target = balances[size - 1] + (amount - sum) / size;
    }
  }
}
