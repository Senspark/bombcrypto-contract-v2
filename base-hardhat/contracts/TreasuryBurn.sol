// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TreasuryBase.sol";

interface IERC20Burnable {
  function burn(uint256 amount) external;
}

/// @title Holds the burn share and destroys it on demand.
contract TreasuryBurn is TreasuryBase {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  event Burned(address indexed token, uint256 amount);

  function burnToken(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(amount > 0, "Amount=0");
    uint256 held = IERC20Upgradeable(token).balanceOf(address(this));
    require(amount <= held, "Exceeds balance");

    IERC20Burnable(token).burn(amount);

    // Verify the balance actually dropped.
    require(IERC20Upgradeable(token).balanceOf(address(this)) == held - amount, "Burn did not take the tokens");
    emit Burned(token, amount);
  }
}
