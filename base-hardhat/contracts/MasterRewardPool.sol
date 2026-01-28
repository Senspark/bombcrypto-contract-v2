// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MasterRewardPool is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  bytes32 public constant DESIGNER_ROLE = keccak256("DESIGNER_ROLE");
  bytes32 public constant TRANSFERER_ROLE = keccak256("TRANSFERER_ROLE");
  bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");
  
  
  address public childPool;

  mapping(address => uint256) public tokenLimits;

  function initialize() public initializer {
    __AccessControl_init();
    __UUPSUpgradeable_init();

    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(UPGRADER_ROLE, msg.sender);
    _grantRole(DESIGNER_ROLE, msg.sender);
    _grantRole(TRANSFERER_ROLE, msg.sender);
    _grantRole(WITHDRAWER_ROLE, msg.sender);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

  function setTokenTransferLimit(address token, uint256 limit) external onlyRole(DESIGNER_ROLE) {
    tokenLimits[token] = limit;
  }

  function setChildPool(address _addr) external onlyRole(DESIGNER_ROLE) {
    childPool = _addr;
  }

  function transferToChildPool(address token) external onlyRole(TRANSFERER_ROLE) {
    require(tokenLimits[token] > 0, 'token limit > 0');
    IERC20Upgradeable(token).transfer(childPool, tokenLimits[token]);
  }

  // Admin function to withdraw
  function adminWithdraw(address receiver, address token, uint256 amount) external onlyRole(WITHDRAWER_ROLE) {
    require(amount > 0, "Amount must be greater than 0");

    // Transfer tokens from this contract to the receiver
    IERC20Upgradeable(token).transfer(receiver, amount);
  }
}
