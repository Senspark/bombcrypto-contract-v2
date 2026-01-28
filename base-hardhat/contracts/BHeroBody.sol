// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

contract BHeroBody is Initializable, AccessControlUpgradeable, UUPSUpgradeable {

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

    /** Upgrades the specified token. */
  // function upgrade(uint256 baseId, uint256 materialId) external {
  //   require(baseId != materialId, "Same token");

  //   address to = msg.sender;
  //   require(ownerOf(baseId) == to && ownerOf(materialId) == to, "Token not owned");

  //   // Check level.
  //   uint256 baseDetails = tokenDetails[baseId];
  //   uint256 materialDetails = tokenDetails[materialId];
  //   uint256 baseLevel = BHeroDetails.decodeLevel(baseDetails);
  //   uint256 materialLevel = BHeroDetails.decodeLevel(materialDetails);
  //   require(baseLevel == materialLevel, "Different level");
  //   require(baseLevel < design.getMaxLevel(), "Max level");

  //   // Transfer coin token.
  //   uint256 rarity = BHeroDetails.decodeRarity(baseDetails);
  //   uint256 cost = getHeroCostByDetails(baseDetails, design.getUpgradeCost(rarity, baseLevel - 1));

  //   coinToken.transferFrom(to, address(this), cost);

  //   uint256 newDetails = BHeroDetails.increaseLevel(baseDetails);
  //   tokenDetails[baseId] = newDetails;
  //   _burn(materialId);

  //   emit TokenUpgraded(to, baseId, materialId);
  //   emit TokenChanged(to, baseId, baseDetails, newDetails);
  // }
}
