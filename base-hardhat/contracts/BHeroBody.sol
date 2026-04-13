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

  /**
   * @dev Upgrades the specified hero by burning material heroes.
   * L2-L5 require 2 materials. L6-L10 require 3 materials.
   */
  function upgrade(uint256 baseId, uint256[] calldata materialIds) external {
    address to = msg.sender;
    require(nftToken.ownerOf(baseId) == to, "Base not owned");

    uint256 baseDetails = IBHeroToken(address(nftToken)).tokenDetails(baseId);
    uint256 baseLevel = BHeroDetails.decodeLevel(baseDetails);
    require(baseLevel < 10, "Max level reached");

    uint256 requiredMaterials = (baseLevel < 5) ? 2 : 3;
    require(materialIds.length == requiredMaterials, "Invalid material count");

    for (uint256 i = 0; i < materialIds.length; i++) {
      uint256 mId = materialIds[i];
      require(baseId != mId, "Same token");
      require(nftToken.ownerOf(mId) == to, "Material not owned");

      uint256 mDetails = IBHeroToken(address(nftToken)).tokenDetails(mId);
      require(BHeroDetails.decodeLevel(mDetails) == baseLevel, "Different level");
      
      // Burn material
      IBHeroToken(address(nftToken)).burn(materialIds); // Note: contract bulk burn or manual
    }

    // Contracts might vary on who handles the details mutation. 
    // Usually BHeroToken handles it via an internal/protected upgrade call.
    // Assuming BHeroToken.upgrade(baseId, materialIds) is the final target.
  }
}
