// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

contract BHeroLegacy is Initializable, AccessControlUpgradeable, UUPSUpgradeable {

  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  bytes32 public constant DESIGNER_ROLE = keccak256("DESIGNER_ROLE");
  bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");

  IERC20 public bcoinToken;
  IERC20 public senToken;
  ERC721Upgradeable public nftToken;

  function initialize(IERC20 bcoinToken_, IERC20 senToken_, ERC721Upgradeable nftToken_) public initializer {
    __AccessControl_init();
    __UUPSUpgradeable_init();
    
    bcoinToken = bcoinToken_;
    senToken = senToken_;
    nftToken = nftToken_;

    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(UPGRADER_ROLE, msg.sender);
    _setupRole(DESIGNER_ROLE, msg.sender);
    _setupRole(WITHDRAWER_ROLE, msg.sender);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

  function supportsInterface(bytes4 interfaceId) public view override(AccessControlUpgradeable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function setBcoinToken(address value) external onlyRole(DESIGNER_ROLE) {
    bcoinToken = IERC20(value);
  }

  function setSenToken(address value) external onlyRole(DESIGNER_ROLE) {
    senToken = IERC20(value);
  }

  function setNFTToken(address value) external onlyRole(DESIGNER_ROLE) {
    nftToken = ERC721Upgradeable(value);
  }
  
}
