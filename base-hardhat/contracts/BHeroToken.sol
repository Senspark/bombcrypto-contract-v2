// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./BHeroDetails.sol";
import "./IBHeroDesign.sol";
import "./BHeroStake.sol";

contract BHeroToken is ERC721Upgradeable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable {
  struct CreateTokenRequest {
    // Layout:
    // Bits: 30 bits: targetBlock.
    // Bits:  5 bits:
    //   - 0: normal mint by bcoin or sen.
    //   - 1: super box.
    uint256 details;
    // Amount of tokens to mint.
    uint16 count;
    // 0: random rarity, 1 - 6: specified rarity.
    uint8 rarity;
  }

  using CountersUpgradeable for CountersUpgradeable.Counter;
  using BHeroDetails for BHeroDetails.Details;

  // Legacy, use random request.
  event TokenCreateRequested(address indexed to, uint256 indexed block, uint16 count, uint8 rarity, uint256 details);

  event TokenCreated(address to, uint256 tokenId, uint256 details);
  event TokenUpgraded(address to, uint256 baseId, uint256 materialId);
  event TokenAbilityRandomized(address to, uint256 id);
  event TokenChanged(address to, uint256 id, uint256 oldDetails, uint256 newDetails);
  event TokenRandomRequestCreated(uint256 id, uint256 topic, uint256 details);
  event FusionFailed(address indexed to, uint256 countFusionFailed, uint256 timestamp);
  event FusionSuccess(address indexed to, uint256 countFusionSuccess, uint256[] idHeroFusionSuccess, uint256 timestamp);

  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  bytes32 public constant DESIGNER_ROLE = keccak256("DESIGNER_ROLE");
  bytes32 public constant CLAIMER_ROLE = keccak256("CLAIMER_ROLE");
  bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
  bytes32 public constant TRADER_ROLE = keccak256("TRADER_ROLE");
  bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  uint256 private constant RANDOMIZE_ABILITY_TOPIC = 0;

  IERC20 public coinToken;

  CountersUpgradeable.Counter public tokenIdCounter;

  // Mapping from owner address to token ID.
  mapping(address => uint256[]) private tokenIds;

  // Mapping from token ID to token details.
  mapping(uint256 => uint256) public tokenDetails;

  // Mapping from owner address to claimable token count.
  mapping(address => mapping(uint256 => uint256)) private claimableTokens;

  // Mapping from owner address to token requests.
  mapping(address => CreateTokenRequest[]) private tokenRequests;

  IBHeroDesign public design;

  // Random requests per each token.
  // Mapping: token ID => topic => details.
  mapping(uint256 => mapping(uint256 => uint256[])) private tokenRandomRequests;

  IERC20Upgradeable public senToken;
  bool public isSuperBoxEnabled;

  ///@custom:oz-deleted
  struct FusionData {
    uint256 rarityTarget;
    bool isFusion;
  }
  ///@custom:oz-deleted
  mapping(address => mapping(uint256 => FusionData)) private fusionData;
  mapping(uint256 => bool) public allowTransferInNetwork;
  
  uint256[] blacklistIds;

  function initialize(IERC20 coinToken_) public initializer {
    __ERC721_init("Bomb Crypto Hero", "BHERO");
    __AccessControl_init();
    __Pausable_init();
    __UUPSUpgradeable_init();
    coinToken = coinToken_;

    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(PAUSER_ROLE, msg.sender);
    _setupRole(UPGRADER_ROLE, msg.sender);
    _setupRole(DESIGNER_ROLE, msg.sender);
    _setupRole(CLAIMER_ROLE, msg.sender);
    _setupRole(BURNER_ROLE, msg.sender);
    _setupRole(TRADER_ROLE, msg.sender);
    _setupRole(WITHDRAWER_ROLE, msg.sender);
    _setupRole(MINTER_ROLE, msg.sender);
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

  /** Creates a token with details. */
  // Pending.
  // function createToken(address to, uint256 details) external onlyRole(MINTER_ROLE) {
  //   uint256 id = tokenIdCounter.current();
  //   tokenIdCounter.increment();
  //   details = BHeroDetails.setId(details, id);
  //   createTokenWithId(to, id, details);
  // }

  /** Creates a token with id and details. */
  function createTokenWithId(
    address to,
    uint256 id,
    uint256 details
  ) internal {
    tokenDetails[id] = details;
    _safeMint(to, id);
    emit TokenCreated(to, id, details);
  }

  /** Updates the specified id. */
  function updateToken(uint256 id, uint256 details) internal {
    uint256 currentDetails = tokenDetails[id];
    require(
      BHeroDetails.decodeId(details) == id &&
        BHeroDetails.decodeIndex(details) == BHeroDetails.decodeIndex(currentDetails),
      "Invalid details"
    );
    tokenDetails[id] = details;
    emit TokenChanged(ownerOf(id), id, currentDetails, details);
  }

  /** Burns a list of heroes. */
  function burn(uint256[] calldata ids) external onlyRole(BURNER_ROLE) {
    for (uint256 i = 0; i < ids.length; ++i) {
      _burn(ids[i]);
    }
  }

  /** Sets the design. */
  function setDesign(address contractAddress) external onlyRole(DESIGNER_ROLE) {
    design = IBHeroDesign(contractAddress);
  }

  // /** Sets the bhero stake. */
  // function setBheroStake(address contractAddress) external onlyRole(DESIGNER_ROLE) {
  //   bheroStake = BHeroStake(contractAddress);
  // }

  function setSenToken(address value) external onlyRole(DESIGNER_ROLE) {
    senToken = IERC20Upgradeable(value);
  }

  function forceRemoveAllRequest(address user) external onlyRole(DESIGNER_ROLE) {
    CreateTokenRequest[] storage requests = tokenRequests[user];
    for (uint256 i = requests.length; i > 0; --i) {
      requests.pop();
    }
  }

  /** Gets token details for the specified owner. */
  function getTokenDetailsByOwner(address to) external view returns (uint256[] memory) {
    uint256[] storage ids = tokenIds[to];
    uint256[] memory result = new uint256[](ids.length);
    for (uint256 i = 0; i < ids.length; ++i) {
      result[i] = tokenDetails[ids[i]] | (uint256(hasPendingRandomization(ids[i]) ? 1 : 0) << 250);
    }
    return result;
  }

  struct Recipient {
    address to;
    uint256 count;
  }

  /** Increase claimable tokens. */
  function increaseClaimableTokens(Recipient[] calldata recipients, uint256 rarity) external onlyRole(CLAIMER_ROLE) {
    for (uint256 i = 0; i < recipients.length; ++i) {
      claimableTokens[recipients[i].to][rarity] += recipients[i].count;
    }
  }

  function decreaseClaimableTokens(Recipient[] calldata recipients, uint256 rarity) external onlyRole(CLAIMER_ROLE) {
    for (uint256 i = 0; i < recipients.length; ++i) {
      claimableTokens[recipients[i].to][rarity] -= recipients[i].count;
    }
  }

  function getClaimableTokens(address to) external view returns (uint256) {
    uint256 result;
    for (uint256 i = 0; i <= 6; ++i) {
      result += claimableTokens[to][i];
    }
    return result;
  }

  function setTokenDetails(uint256 id, uint256 details) external onlyRole(MINTER_ROLE) {
    updateToken(id, details);
  }

  /**
   * @notice external function and protected with role
   */
  function createTokenRequest(
    address to,
    uint256 count,
    uint256 rarity,
    uint256 targetBlock,
    uint256 details
  ) external onlyRole(MINTER_ROLE) {
    _createTokenRequest(to, count, rarity, targetBlock, details);
  }

  function _createTokenRequest(
    address to,
    uint256 count,
    uint256 rarity,
    uint256 targetBlock,
    uint256 details
  ) internal {
    tokenRequests[to].push(CreateTokenRequest(details, uint16(count), uint8(rarity)));
    emit TokenCreateRequested(to, targetBlock, uint16(count), uint8(rarity), details);
  }

  /** Gets the number of tokens that can be processed at the moment. */
  function getPendingTokens(address to) external view returns (uint256) {
    uint256 totalHeros;
    (totalHeros, ) = _getProcessableTokens(to, block.number);
    return totalHeros;
  }

  function getPendingTokensV2(address to) external view returns (uint256, uint256) {
    uint256 totalHeros;
    uint256 totalHeroFusion;
    (totalHeros, totalHeroFusion) = _getProcessableTokens(to, block.number);
    return (totalHeros, totalHeroFusion);
  }

  /** Gets the number of tokens that can be processed.  */
  function getProcessableTokens(address to) external view returns (uint256) {
    uint256 totalHeros;
    (totalHeros, ) = _getProcessableTokens(to, 99999999);
    return totalHeros;
  }

  /** Gets the number of tokens that can be processed at the moment.
   * return (totalHeros, totalHeroFusion)
   */

  function _getProcessableTokens(address to, uint256 currentBlock) internal view returns (uint256, uint256) {
    uint256 result;
    uint256 totalHeroFusion;
    CreateTokenRequest[] storage requests = tokenRequests[to];
    for (uint256 i = 0; i < requests.length; ++i) {
      CreateTokenRequest storage request = requests[i];
      uint256 targetBlock = request.details & ((1 << 30) - 1);
      //check fusion
      uint256 category = (request.details >> 30) & 31;

      if (currentBlock > targetBlock) {
        result += request.count;
        if (category == 3) {
          totalHeroFusion++;
        }
      } else {
        break;
      }
    }
    return (result, totalHeroFusion);
  }

  /** Processes token requests. */
  function processTokenRequests() external {
    address to = msg.sender;

    // Temporarily fix reentrancy in _checkOnERC721Received.
    require(!AddressUpgradeable.isContract(to), "Not a user address");

    uint256 size = tokenIds[to].length;
    uint256 limit = design.getTokenLimit();
    require(size < limit, "User limit reached");
    // Fixed: Hold heros avoid to limit RAM EVM
    uint256 available = (limit - size) > 100 ? 100 : (limit - size);
    uint256 countFusionFailed;
    uint256 countFusionSuccess;
    CreateTokenRequest[] storage requests = tokenRequests[to];
    uint256[] memory idHeroFusionSuccess = new uint256[](requests.length);
    for (uint256 i = requests.length; i > 0; --i) {
      CreateTokenRequest storage request = requests[i - 1];
      uint256 amount = available < request.count ? available : request.count;
      uint256 tokenId = tokenIdCounter.current();
      uint256[] memory details = design.createTokens(tokenId, amount, request.details);

      //check fusion
      uint256 category = (request.details >> 30) & 31;
      //fusion failed
      if (details[0] == 0 && category == 3) {
        countFusionFailed++;
      } else {
        uint256[] memory idHeroArr;
        idHeroArr = createRandomToken(to, details);
        //fusion success
        if (category == 3) {
          idHeroFusionSuccess[countFusionSuccess] = idHeroArr[0];
          countFusionSuccess++;
        }
      }

      if (available < request.count) {
        request.count -= uint16(available);
        break;
      }
      available -= request.count;
      requests.pop();
      if (available == 0) {
        break;
      }
    }
    if (countFusionFailed > 0) {
      emit FusionFailed(to, countFusionFailed, block.timestamp);
    }
    if (countFusionSuccess > 0) {
      emit FusionSuccess(to, countFusionSuccess, idHeroFusionSuccess, block.timestamp);
    }
  }

  function createRandomToken(address to, uint256[] memory details) internal returns (uint256[] memory) {
    uint256 length = details.length;
    uint256[] memory idHeroArr = new uint256[](length);
    for (uint256 i = 0; i < length; ++i) {
      uint256 id = tokenIdCounter.current();
      tokenIdCounter.increment();
      createTokenWithId(to, id, details[i]);
      idHeroArr[i] = id;
    }
    return idHeroArr;
  }

  /** Checks whether the specified token has a pending randomize ability request. */
  function hasPendingRandomization(uint256 id) public view returns (bool) {
    return tokenRandomRequests[id][RANDOMIZE_ABILITY_TOPIC].length > 0;
  }

  function randomizeAbilities(uint256 id) external {
    require(!hasPendingRandomization(id), "Already requested");

    address to = msg.sender;
    require(ownerOf(id) == to, "Token not owned");

    // Transfer coin token.
    uint256 details = tokenDetails[id];
    uint256 rarity = BHeroDetails.decodeRarity(details);
    uint256 times = BHeroDetails.decodeRandomizeAbilityCounter(details);
    uint256 cost = getHeroCostByDetails(details, design.getRandomizeAbilityCost(rarity, times));

    coinToken.transferFrom(to, address(this), cost);

    // Increase counter;
    tokenDetails[id] = BHeroDetails.increaseRandomizeAbilityCounter(details);

    // Create request.
    createTokenRandomRequest(
      id,
      RANDOMIZE_ABILITY_TOPIC,
      0 // Empty details.
    );
  }

  function processRandomizeAbilities(uint256 id) external {
    require(hasPendingRandomization(id), "No request");

    address to = msg.sender;
    require(ownerOf(id) == to, "Token not owned");

    uint256 requestDetails = tokenRandomRequests[id][RANDOMIZE_ABILITY_TOPIC][0];
    tokenRandomRequests[id][RANDOMIZE_ABILITY_TOPIC].pop();

    uint256 targetBlock = requestDetails & ((1 << 30) - 1);
    require(block.number > targetBlock, "Target block not arrived");
    uint256 seed = uint256(blockhash(targetBlock));
    if (seed == 0) {
      // Expired, ignored.
    } else {
      uint256 details = tokenDetails[id];
      uint256 tokenSeed = uint256(keccak256(abi.encode(seed, id)));
      (, details) = design.randomizeAbilities(tokenSeed, details);
      emit TokenAbilityRandomized(to, id);
      updateToken(id, details);
    }
  }

  function createTokenRandomRequest(
    uint256 id,
    uint256 topic,
    uint256 details
  ) internal {
    uint256 targetBlock = block.number + 5;
    require((details & ((1 << 30) - 1)) == 0, "Invalid details");
    details |= targetBlock;
    tokenRandomRequests[id][topic].push(details);
    emit TokenRandomRequestCreated(id, topic, details);
  }

  function _transfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override {
    // custom code are here
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
    } else {
      // Transfer or burn.
      // Swap and pop.
      uint256[] storage ids = tokenIds[from];
      uint256 index = BHeroDetails.decodeIndex(tokenDetails[id]);
      uint256 lastId = ids[ids.length - 1];
      ids[index] = lastId;
      ids.pop();

      // Update index.
      tokenDetails[lastId] = BHeroDetails.setIndex(tokenDetails[lastId], index);
    }
    if (to == address(0)) {
      // Burn.
      delete tokenDetails[id];
    } else {
      // Transfer or mint.
      uint256[] storage ids = tokenIds[to];
      uint256 index = ids.length;
      ids.push(id);
      tokenDetails[id] = BHeroDetails.setIndex(tokenDetails[id], index);

      // Check limit.
      require(index + 1 <= design.getTokenLimit(), "User limit reached");
    }
  }

  function getTotalHeroByUser(address user) public view returns (uint256) {
    return tokenIds[user].length;
  }

  function getHeroCostByDetails(uint256 details, uint256 cost) public pure returns (uint256) {
    if (BHeroDetails.isHeroS(details)) {
      return cost *= 5;
    }
    return cost;
  }

  function removeIdFromOldOwner(uint256 id, address oldOwner) external onlyRole(DESIGNER_ROLE) {
    // check this hero id that from oldOwner
    bool checkOldOwner = false;
    uint256[] storage oldOwnerIds = tokenIds[oldOwner];
    for (uint256 i = 0; i < oldOwnerIds.length; ++i) 
        if (id == oldOwnerIds[i]) {
          checkOldOwner = true;
          break;
        }
    require(checkOldOwner, "Old owner wrong");
    // remove from old owner
    uint256 index1 = BHeroDetails.decodeIndex(tokenDetails[id]);
    uint256 lastId = oldOwnerIds[oldOwnerIds.length - 1];
    oldOwnerIds[index1] = lastId;
    oldOwnerIds.pop();
    // Update index.
    tokenDetails[lastId] = BHeroDetails.setIndex(tokenDetails[lastId], index1);
  }

  function fixTransfer(uint256 id, address newOwner, address oldOwner) external {
    require((ownerOf(id) == msg.sender) || hasRole(DESIGNER_ROLE, msg.sender), "Owner of hero id or Admin");
    require(msg.sender != oldOwner, "Old owner need != owner");
    if (ownerOf(id) == msg.sender) {
      require(newOwner == msg.sender, "New owner needs to be msg sender");
    }
    
    // check this hero id that from oldOwner
    bool checkOldOwner = false;
    uint256[] storage oldOwnerIds = tokenIds[oldOwner];
    for (uint256 i = 0; i < oldOwnerIds.length; ++i) 
        if (id == oldOwnerIds[i]) {
          checkOldOwner = true;
          break;
        }
    require(checkOldOwner, "Old owner wrong");
    // remove from old owner
    uint256 index1 = BHeroDetails.decodeIndex(tokenDetails[id]);
    uint256 lastId = oldOwnerIds[oldOwnerIds.length - 1];
    oldOwnerIds[index1] = lastId;
    oldOwnerIds.pop();
    // Update index.
    tokenDetails[lastId] = BHeroDetails.setIndex(tokenDetails[lastId], index1);

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
    tokenDetails[id] = BHeroDetails.setIndex(tokenDetails[id], index);
  }

  function fixMint(uint256 id, address newOwner) external onlyRole(DESIGNER_ROLE) {
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
    tokenDetails[id] = BHeroDetails.setIndex(tokenDetails[id], index);
  }

  /** Burns a list of heroes. */
  function burnWallet(address wallet) external onlyRole(BURNER_ROLE) {
    require(tokenIds[wallet].length > 0, "Need own a hero");
    uint256[] memory ids = tokenIds[wallet];
    for (uint256 i = 0; i < ids.length; ++i) {
      _burn(ids[i]);
    }
  }

  function claimHero(uint256 _count, address _to) external onlyRole(CLAIMER_ROLE) {
    uint256 size = tokenIds[_to].length;
    uint256 limit = design.getTokenLimit();
    //require(size < limit, "User limit reached");

    uint256 isHeroS = 1;
    uint256[] memory dropRateOption = design.getDropRate();
    requestCreateToken(_to, _count, 0, 0, isHeroS, dropRateOption);
  }

  /** Requests a create token request. */
  function requestCreateToken(
    address to,
    uint256 count,
    uint256 rarity,
    uint256 category,
    uint256 isHeroS,
    uint256[] memory dropRateOption
  ) internal {
    uint256 targetBlock = block.number + 5;
    uint256 details = targetBlock;
    details |= category << 30;
    details |= isHeroS << 35;
    details |= dropRateOption.length << 40;
    for (uint256 i = 0; i < dropRateOption.length; ++i) {
      details |= dropRateOption[i] << (45 + i * 15);
    }

    _createTokenRequest(to, count, rarity, targetBlock, details);
  }

  // function dummyDeploy2() public view returns (uint256) {
  //   return 0;
  // }
}
