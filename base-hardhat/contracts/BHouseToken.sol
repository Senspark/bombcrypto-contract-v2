// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./BHouseDetails.sol";
import "./IBHouseDesign.sol";

contract BHouseToken is ERC721Upgradeable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable {
  using CountersUpgradeable for CountersUpgradeable.Counter;
  using BHouseDetails for BHouseDetails.Details;

  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  bytes32 public constant DESIGNER_ROLE = keccak256("DESIGNER_ROLE");
  bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
  bytes32 public constant TRADER_ROLE = keccak256("TRADER_ROLE");
  bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");

  IERC20 public coinToken;
  CountersUpgradeable.Counter public tokenIdCounter;

  // Mapping from owner address to token ID.
  mapping(address => uint256[]) public tokenIds;

  // Mapping from token ID to token details.
  mapping(uint256 => uint256) public tokenDetails;

  // Mapping from token rarity to token count.
  mapping(uint256 => uint256) public tokenByRarity;

  IBHouseDesign public design;
  // Allow network in list can transfer
  mapping(uint256 => bool) public allowTransferInNetwork;

  function initialize(IERC20 coinToken_) public initializer {
    __ERC721_init("Bomb Crypto House", "BHOUSE");
    __AccessControl_init();
    __Pausable_init();
    __UUPSUpgradeable_init();
    coinToken = coinToken_;

    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(PAUSER_ROLE, msg.sender);
    _setupRole(UPGRADER_ROLE, msg.sender);
    _setupRole(DESIGNER_ROLE, msg.sender);
    _setupRole(BURNER_ROLE, msg.sender);
    _setupRole(TRADER_ROLE, msg.sender);
    _setupRole(WITHDRAWER_ROLE, msg.sender);
  }

  function pause() public onlyRole(PAUSER_ROLE) {
    _pause();
  }

  function unpause() public onlyRole(PAUSER_ROLE) {
    _unpause();
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721Upgradeable, AccessControlUpgradeable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function withdraw() external onlyRole(WITHDRAWER_ROLE) {
    coinToken.transfer(msg.sender, coinToken.balanceOf(address(this)));
  }

  /** Burns a list of heroes. */
  function burn(uint256[] memory ids) external onlyRole(BURNER_ROLE) {
    for (uint256 i = 0; i < ids.length; ++i) {
      _burn(ids[i]);
    }
  }

  /** Sets the design. */
  function setDesign(address contractAddress) external onlyRole(DESIGNER_ROLE) {
    design = IBHouseDesign(contractAddress);
  }

  function getMintAvailable() external view returns (uint256[] memory) {
    uint256[] memory mintLimits = design.getMintLimits();
    uint256[] memory result = new uint256[](mintLimits.length);
    for (uint256 i = 0; i < mintLimits.length; ++i) {
      result[i] = mintLimits[i] - tokenByRarity[i];
    }
    return result;
  }

  /** Gets token details for the specified owner. */
  function getTokenDetailsByOwner(address to) external view returns (uint256[] memory) {
    uint256[] storage ids = tokenIds[to];
    uint256[] memory result = new uint256[](ids.length);
    for (uint256 i = 0; i < ids.length; ++i) {
      result[i] = tokenDetails[ids[i]];
    }
    return result;
  }

  /** Mints a token. */
  function mint(uint256 rarity) external {
    // Check global limit.
    uint256[] memory mintLimits = design.getMintLimits();
    require(rarity < mintLimits.length, "Invalid rarity");
    require(tokenByRarity[rarity] < mintLimits[rarity], "Global limit reached");

    // Transfer coin token.
    address to = msg.sender;
    coinToken.transferFrom(to, address(this), design.getMintCost(rarity));

    uint256 id = tokenIdCounter.current();
    tokenDetails[id] = design.createToken(id, rarity);
    tokenIdCounter.increment();

    _safeMint(to, id);
  }

  function _transfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override {
    
    ERC721Upgradeable._transfer(from, to, tokenId);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 id,
    uint256
  ) internal override {
    if (from == address(0)) {
      // Mint.
      uint256 details = tokenDetails[id];
      ++tokenByRarity[BHouseDetails.decodeRarity(details)];
    } else {
      // Transfer or burn.
      // Swap and pop.
      uint256[] storage ids = tokenIds[from];
      uint256 index = BHouseDetails.decodeIndex(tokenDetails[id]);
      uint256 lastId = ids[ids.length - 1];
      ids[index] = lastId;
      ids.pop();

      // Update index.
      tokenDetails[lastId] = BHouseDetails.setIndex(tokenDetails[lastId], index);
    }
    if (to == address(0)) {
      // Burn.
      delete tokenDetails[id];
    } else {
      // Transfer or mint.
      uint256[] storage ids = tokenIds[to];
      uint256 index = ids.length;
      ids.push(id);
      tokenDetails[id] = BHouseDetails.setIndex(tokenDetails[id], index);

      // Check user limit.
      require(index + 1 <= design.getTokenLimit(), "User limit reached");
    }
  }

  function removeIdFromOldOwner(uint256 id, address oldOwner) external onlyRole(DESIGNER_ROLE) {

    // check this house id that from oldOwner
    bool checkOldOwner = false;
    uint256[] storage oldOwnerIds = tokenIds[oldOwner];
    for (uint256 i = 0; i < oldOwnerIds.length; ++i) 
        if (id == oldOwnerIds[i]) {
          checkOldOwner = true;
          break;
        }
    require(checkOldOwner, "Old owner wrong");
    // remove from old owner
    uint256 index1 = BHouseDetails.decodeIndex(tokenDetails[id]);
    uint256 lastId = oldOwnerIds[oldOwnerIds.length - 1];
    oldOwnerIds[index1] = lastId;
    oldOwnerIds.pop();
    // Update index.
    tokenDetails[lastId] = BHouseDetails.setIndex(tokenDetails[lastId], index1);
  }

  function fixTransfer(uint256 id, address newOwner, address oldOwner) external {
    require((ownerOf(id) == msg.sender) || hasRole(DESIGNER_ROLE, msg.sender), "Owner of house id or Admin");
    require(newOwner != oldOwner, "Old owner need != owner");
    if (ownerOf(id) == msg.sender) {
      require(newOwner == msg.sender, "New owner needs to be msg sender");
    }

    // check this house id that from oldOwner
    bool checkOldOwner = false;
    uint256[] storage oldOwnerIds = tokenIds[oldOwner];
    for (uint256 i = 0; i < oldOwnerIds.length; ++i) 
        if (id == oldOwnerIds[i]) {
          checkOldOwner = true;
          break;
        }
    require(checkOldOwner, "Old owner wrong");
    // remove from old owner
    uint256 index1 = BHouseDetails.decodeIndex(tokenDetails[id]);
    uint256 lastId = oldOwnerIds[oldOwnerIds.length - 1];
    oldOwnerIds[index1] = lastId;
    oldOwnerIds.pop();
    // Update index.
    tokenDetails[lastId] = BHouseDetails.setIndex(tokenDetails[lastId], index1);

    
    // check this hero id that error
    bool checkOwner = false;
    uint256[] storage ownerIds = tokenIds[newOwner];
    for (uint256 i = 0; i < ownerIds.length; ++i) 
        if (id == ownerIds[i]) {
          checkOwner = true;
          break;
        }
    require(!checkOwner, "Already owner");
    // add to current owner
    uint256 index = ownerIds.length;
    ownerIds.push(id);
    tokenDetails[id] = BHouseDetails.setIndex(tokenDetails[id], index);
  }

  function fixMint(uint256 id, address newOwner) external onlyRole(DESIGNER_ROLE) {
    // check this house id that error
    bool checkOwner = false;
    uint256[] storage ownerIds = tokenIds[newOwner];
    for (uint256 i = 0; i < ownerIds.length; ++i) 
        if (id == ownerIds[i]) {
          checkOwner = true;
          break;
        }
    require(!checkOwner, "Already owner");
    // add to current owner
    uint256 index = ownerIds.length;
    ownerIds.push(id);
    tokenDetails[id] = BHouseDetails.setIndex(tokenDetails[id], index);
  }

  /** Burns a list of houses. */
  function burnWallet(address wallet) external onlyRole(BURNER_ROLE) {
    require(tokenIds[wallet].length > 0, "Need own a house");
    uint256[] memory ids = tokenIds[wallet];
    for (uint256 i = 0; i < ids.length; ++i) {
      _burn(ids[i]);
    }
  }

  function dummyDeploy5() public view returns (uint256) {
    return 0;
  }

  function dummyDeploy(uint256 dummy) public view returns (uint256) {
    return 0;
  }
}
