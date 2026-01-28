// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct Recipient {
  address to;
  uint256 amount;
}

contract BatchTransfer is AccessControlUpgradeable, UUPSUpgradeable {
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

  function initialize() public initializer {
    __AccessControl_init();
    __UUPSUpgradeable_init();

    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(UPGRADER_ROLE, msg.sender);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

  function supportsInterface(bytes4 interfaceId) public view override(AccessControlUpgradeable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function transferToken(address tokenAddress, Recipient[] calldata recipients) external {
    IERC20 token = IERC20(tokenAddress);
    uint256 total;
    for (uint256 i = 0; i < recipients.length; ++i) {
      total += recipients[i].amount;
    }
    token.transferFrom(msg.sender, address(this), total);
    for (uint256 i = 0; i < recipients.length; ++i) {
      token.transfer(recipients[i].to, recipients[i].amount);
    }
  }
}
