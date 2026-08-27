// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/// @title Holds tokens received from TreasurySplitter. No swap, no ratios, no reference to the splitter.
abstract contract TreasuryBase is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

  event Withdrawn(address indexed token, address indexed receiver, uint256 amount);

  function initialize() public initializer {
    __AccessControl_init();
    __UUPSUpgradeable_init();

    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(UPGRADER_ROLE, msg.sender);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

  function withdrawTo(address token, address receiver, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(receiver != address(0), "Zero address");
    require(amount > 0, "Amount=0");
    IERC20Upgradeable(token).safeTransfer(receiver, amount);
    emit Withdrawn(token, receiver, amount);
  }

  function balanceOf(address token) external view returns (uint256) {
    return IERC20Upgradeable(token).balanceOf(address(this));
  }
}

// Separate proxies over identical logic, so the explorer shows the real name of each.
contract TreasuryCommunity is TreasuryBase {}

contract TreasuryMarketing is TreasuryBase {}
