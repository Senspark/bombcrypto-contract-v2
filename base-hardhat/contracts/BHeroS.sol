// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./BHeroToken.sol";
import "./BHeroDetails.sol";
import "./signatureV1Lib.sol";

//maybe: reset shield term in contract that is repair shield term in game/community

contract BHeroS is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
  using BHeroDetails for BHeroDetails.Details;

  // Legacy, use random request.
  event TokenCreateRequested(address to, uint256 block);
  event CreateRock(address indexed owner, uint256 numRock, uint256[] listIdHero);
  event BurnResetShield(address indexed owner, uint256 idHeroS, uint256[] listIdHero);
  event ResetShieldHeroS(address indexed owner, uint256 idHeroS, uint256 numRock);
  event UpgradeShieldLevel(address indexed owner, uint256 idHeroS, uint256 oldLevel, uint256 newLevel);
  event SetShieldLevel(address indexed owner, uint256 idHeroS, uint256 oldLevel, uint256 newLevel);
  event Fusion(
    address indexed owner,
    uint256[] mainMaterials,
    uint256[] buffMaterials,
    uint256 rarityMain,
    uint256 rarityTarget
  );

  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  bytes32 public constant DESIGNER_ROLE = keccak256("DESIGNER_ROLE");
  bytes32 public constant CLAIMER_ROLE = keccak256("CLAIMER_ROLE");

  BHeroToken public bHeroToken;

  uint256 maxBurn;
  //create rock from Hero type
  uint8[6] numRockCreate;
  //number rock need to reset shield
  uint8[6] numRockResetShield;

  //User info
  struct UserInfo {
    uint256 totalRock;
    //using for exchange
    uint256[] numRock;
    uint256[] priceRock;
  }

  mapping(address => UserInfo) userInfos;

  IERC20 public bcoinToken;
  IERC20 public senToken;

  bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");

  /*
  uint256[] public bcoinRockPackPrices;
  uint256[] public senRockPackPrices;
  uint256[] public numRockPacks;
  */

  mapping(address => mapping(uint256 => bool)) public usedNonces;

  function initialize(BHeroToken bHeroTokenVal) public initializer {
    __AccessControl_init();
    __UUPSUpgradeable_init();

    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(UPGRADER_ROLE, msg.sender);
    _grantRole(DESIGNER_ROLE, msg.sender);
    _grantRole(CLAIMER_ROLE, msg.sender);

    bHeroToken = bHeroTokenVal;
    maxBurn = 5;
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

  modifier isOwner(uint256[] calldata listToken) {
    _isOwner(listToken);
    _;
  }

  modifier isMaxBurn(uint256[] calldata listToken) {
    _isMaxBurn(listToken);
    _;
  }

  modifier checkNumRock(address owner, uint256 numRock) {
    require(numRock > 0, "Rock < 1");
    require(userInfos[owner].totalRock >= numRock, "Not enough rocks");
    _;
  }

  modifier canFusion(uint256[] calldata mainMaterials, uint256[] calldata buffMaterials) {
    uint256 countMain = mainMaterials.length;
    require(countMain > 2 && countMain < 5, "Not enough Hero main materials");
    require(_isSameRarity(mainMaterials), "Rarity not same");
    _isOwner(mainMaterials);
    _isOwner(buffMaterials);
    _;
  }

  modifier checkBurnResetShield(uint256 idHeroS, uint256[] calldata listIdHero) {
    uint256 detailHeroS = getTokenDetailByID(idHeroS);

    //Estimation fee gas
    require(BHeroDetails.isHeroS(detailHeroS), "not HeroS");
    bool checkNumHero = checkNumHeroBurn(detailHeroS, listIdHero);
    require(checkNumHero, "not enough Hero burn");

    for (uint256 i = 0; i < listIdHero.length; ++i) {
      bool check = isCommonHero(getTokenDetailByID(listIdHero[i]));
      require(check, "not common Hero");
    }

    _;
  }

  function checkNumHeroBurn(uint256 detailHeroS, uint256[] memory listIdHero) public pure returns (bool) {
    uint256 rarityHeroS = BHeroDetails.decodeRarity(detailHeroS);

    uint8[6] memory numHero = [1, 1, 2, 3, 4, 5];
    return listIdHero.length == numHero[rarityHeroS];
  }

  function isCommonHero(uint256 detail) public pure returns (bool) {
    uint256 rarity = BHeroDetails.decodeRarity(detail);
    return rarity == 0;
  }

  //Get num rock when burn hero type
  function getNumRock(uint256[] memory listIdHero) internal view returns (uint256) {
    uint256 totalRock;
    for (uint256 i = 0; i < listIdHero.length; ++i) {
      uint256 rarity = BHeroDetails.decodeRarity(getTokenDetailByID(listIdHero[i]));
      totalRock += numRockCreate[rarity];
    }
    return totalRock;
  }

  // Estimation fee gas modifier with internal function
  function _isMaxBurn(uint256[] calldata listToken) internal view {
    uint256 length = listToken.length;
    require(length == maxBurn, "Not equal max burn");
  }

  function _isOwner(uint256[] calldata listToken) internal view {
    address owner = msg.sender;
    uint256 length = listToken.length;
    for (uint256 i = 0; i < length; ++i) {
      require(owner == bHeroToken.ownerOf(listToken[i]), "Not owner");
    }
  }

  function setMaxBurn(uint256 maxBurnVal) external onlyRole(DESIGNER_ROLE) {
    maxBurn = maxBurnVal;
  }

  /**
   * polygon: [5,10,20,35,55,80]
   * BSC: [1,2,3,4,5,6]
   */
  function setNumRockCreate(uint8[6] memory value) external onlyRole(DESIGNER_ROLE) {
    numRockCreate = value;
  }

  /**
   * polygon: [1,2,4,6,8,10]
   * BSC: [1,1,2,3,4,5]
   */
  function setNumRockResetShield(uint8[6] memory value) external onlyRole(DESIGNER_ROLE) {
    numRockResetShield = value;
  }

  function addRockByAdmin(address user, uint value) external onlyRole(DESIGNER_ROLE) {
    userInfos[user].totalRock += value;
  }

  // @title  Burn list Here
  function burnListToken(uint256[] calldata listToken) external isMaxBurn(listToken) isOwner(listToken) {
    uint256 length = listToken.length;
    uint256[] memory heroTypes = new uint256[](length);
    for (uint256 i = 0; i < length; ++i) {
      uint256 rarity = BHeroDetails.decodeRarity(getTokenDetailByID(listToken[i]));
      heroTypes[i] = rarity;
    }

    //@notice burn listoken
    bHeroToken.burn(listToken);

    uint256[] memory dropRateOption = getPercentHeroS(heroTypes);

    //requestCreateToken
    uint256 isHeroS = 1;
    requestCreateToken(msg.sender, 1, BHeroDetails.ALL_RARITY, 0, isHeroS, dropRateOption);
  }

  function getPercentHeroS(uint256[] memory heroTypes) public pure returns (uint256[] memory) {
    uint256[] memory dropRate = new uint256[](6);

    for (uint256 i = 0; i < heroTypes.length; ++i) {
      dropRate[heroTypes[i]]++;
    }
    return dropRate;
  }

  function requestCreateToken(
    address to,
    uint256 count,
    uint256 rarity,
    uint256 category,
    uint256 isHeroS,
    uint256[] memory dropRateOption
  ) internal {
    uint256 targetBlock = block.number + 5;
    uint256 value;
    value |= dropRateOption.length << 40;
    for (uint256 i = 0; i < dropRateOption.length; ++i) {
      value |= dropRateOption[i] << (45 + i * 15);
    }
    uint256 details = targetBlock | (category << 30) | (isHeroS << 35) | value;

    bHeroToken.createTokenRequest(to, count, rarity, targetBlock, details);

    emit TokenCreateRequested(to, targetBlock);
  }

  function getTokenDetailByID(uint256 id) internal view returns (uint256) {
    return bHeroToken.tokenDetails(id);
  }

  /**
   * Mints tokens.
   */
  function mint(uint256 count) external {
    require(count > 0, "No token to mint");

    address user = msg.sender;
    uint256 requestCategory;
    uint256 heroCount;

    uint256 costBcoin = bHeroToken.design().getMintCostHeroS() * count;
    bcoinToken.transferFrom(user, address(this), costBcoin);

    uint256 costSen = bHeroToken.design().getSenMintCostHeroS() * count;
    senToken.transferFrom(user, address(this), costSen);

    heroCount = count;
    requestCategory = 0;

    // Check limit.
    // require(bHeroToken.getTotalHeroByUser(user) + count <= bHeroToken.design().getTokenLimit(), "User limit reached");

    // requestCreateToken
    uint256 isHeroS = 1;
    requestCreateToken(
      user,
      heroCount,
      BHeroDetails.ALL_RARITY,
      requestCategory,
      isHeroS,
      bHeroToken.design().getDropRateHeroS()
    );
  }

  function claimHeroS(address user, uint256 heroCount, uint256[] memory ratioHeroS) external onlyRole(CLAIMER_ROLE) {
    uint256 requestCategory = 0;
    uint256 isHeroS = 1;
    requestCreateToken(user, heroCount, BHeroDetails.ALL_RARITY, requestCategory, isHeroS, ratioHeroS);
  }

  /**
   * @dev set shield level
   */
  function setShieldLevel(address owner, uint256 idHeroS, uint256 levelLabel) external onlyRole(DESIGNER_ROLE) {
    uint256 rarity;
    uint256 level;
    uint256 detailHeroS;
    (rarity, level, detailHeroS) = _getHeroInfo(owner, idHeroS);
    require(levelLabel < 5, "Max level is 4");

    //sync level in blockchain
    uint256 newLevel = levelLabel - 1;
    uint256 newDetails = BHeroDetails.setShieldLevel(detailHeroS, newLevel);
    bHeroToken.setTokenDetails(idHeroS, newDetails);
    //event save label level
    uint256 oldLevel = level;
    emit SetShieldLevel(owner, idHeroS, oldLevel, newLevel);
  }

  /**
   * Burn hero and create Rock
   */
  function createRock(uint256[] calldata listIdHero) external isOwner(listIdHero) {
    uint256 numRock = getNumRock(listIdHero);

    //add data
    address owner = msg.sender;
    userInfos[owner].totalRock += numRock;

    //@notice burn listoken
    bHeroToken.burn(listIdHero);

    //event
    emit CreateRock(owner, numRock, listIdHero);
  }

  function _getHeroInfo(address owner, uint256 idHeroS) internal view returns (uint256, uint256, uint256) {
    require(owner == bHeroToken.ownerOf(idHeroS), "Not owner");

    uint256 detailHeroS = getTokenDetailByID(idHeroS);
    //require(BHeroDetails.isHeroS(detailHeroS), "Not HeroS");

    uint256 rarity = BHeroDetails.decodeRarity(detailHeroS);
    uint256 level = BHeroDetails.decodeShieldLevel(detailHeroS) + 1;

    return (rarity, level, detailHeroS);
  }

  //User need number Rock for reset shield HeroS
  function resetShieldHeroS(uint256 idHeroS, uint256 numRock) external checkNumRock(msg.sender, numRock) {
    address owner = msg.sender;
    uint256 rarity;
    uint256 level;
    uint256 detailHeroS;
    (rarity, level, detailHeroS) = _getHeroInfo(owner, idHeroS);

    require(numRockResetShield[rarity] * level == numRock, "Not enough rocks to reset");
    //update data
    userInfos[owner].totalRock -= numRock;

    uint256 newDetails = BHeroDetails.increaseNumResetShield(detailHeroS);
    bHeroToken.setTokenDetails(idHeroS, newDetails);

    emit ResetShieldHeroS(owner, idHeroS, numRock);
  }

  //Upgrade shield level with num rocks needed
  /*function upgradeShieldLevel(uint256 idHeroS, uint256 numRock) external checkNumRock(msg.sender, numRock) {
    address owner = msg.sender;
    uint256 rarity;
    uint256 level;
    uint256 detailHeroS;
    (rarity, level, detailHeroS) = _getHeroInfo(owner, idHeroS);

    require(level < 4, "have max level");

    uint256 numRockUpgrade = bHeroToken.design().getRockUpgradeShieldLevel(rarity, level);

    require(numRockUpgrade == numRock, "Not enough rocks to upgrade");

    //update data
    userInfos[owner].totalRock -= numRock;

    uint256 newDetails = BHeroDetails.increaseShieldLevel(detailHeroS);
    bHeroToken.setTokenDetails(idHeroS, newDetails);

    //event save label level
    uint256 oldLevel = level;
    uint256 newLevel = level + 1;

    emit UpgradeShieldLevel(owner, idHeroS, numRock, oldLevel, newLevel);
  }*/

  function upgradeShieldLevel(uint256 idHeroS, uint256 nonce, bytes memory signature) external {
    //console.log("Upgrade shield %s %s", heroId, nonce);
    //console.log("Signature:");
    //console.logBytes(signature);

    // Mỗi nonce chỉ cho phép dùng 1 lần
    require(!usedNonces[msg.sender][nonce], "Nonce has used");
    usedNonces[msg.sender][nonce] = true;

    bytes32 rawMessage = keccak256(abi.encodePacked(msg.sender, idHeroS, nonce));
    bytes32 message = getEncodeMessage(rawMessage);
    require(_verify(message, signature), "Message isn't correct");

    // tiến hành repair shield

    address owner = msg.sender;
    uint256 rarity;
    uint256 level;
    uint256 detailHeroS;
    (rarity, level, detailHeroS) = _getHeroInfo(owner, idHeroS);

    require(level < 4, "have max level");

    //uint256 numRockUpgrade = bHeroToken.design().getRockUpgradeShieldLevel(rarity, level);

    //require(numRockUpgrade == numRock, "Not enough rocks to upgrade");

    //update data
    //userInfos[owner].totalRock -= numRock;

    uint256 newDetails = BHeroDetails.increaseShieldLevel(detailHeroS);
    bHeroToken.setTokenDetails(idHeroS, newDetails);

    //event save label level
    uint256 oldLevel = level;
    uint256 newLevel = level + 1;

    emit UpgradeShieldLevel(owner, idHeroS, oldLevel, newLevel);
  }

  function getEncodeMessage(bytes32 rawMessage) internal pure returns (bytes32 message) {
    bytes memory s = abi.encodePacked(rawMessage);
    message = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", StringsUpgradeable.toString(s.length), s));
  }

  function _verify(bytes32 message, bytes memory signature) public view returns (bool) {
    address signer = signtureERC721.checkMessageSignature(message, signature);
    return hasRole(DESIGNER_ROLE, signer);
  }

  function getTotalRockByUser(address user) public view returns (uint256) {
    return userInfos[user].totalRock;
  }

  /**
   * Burn hero and reset shield for HeroS
   */
  function burnResetShield(
    uint256 idHeroS,
    uint256[] calldata listIdHero
  ) external isOwner(listIdHero) checkBurnResetShield(idHeroS, listIdHero) {
    address owner = msg.sender;
    require(owner == bHeroToken.ownerOf(idHeroS), "Not owner");

    //@notice burn listoken
    bHeroToken.burn(listIdHero);

    //add data
    uint256 detail = getTokenDetailByID(idHeroS);
    uint256 newDetails = BHeroDetails.increaseNumResetShield(detail);
    bHeroToken.setTokenDetails(idHeroS, newDetails);

    //event
    emit BurnResetShield(owner, idHeroS, listIdHero);
  }

  /**
   * @dev burn hero and fusion new hero
   * @param mainMaterials: array list heroS main materials
   * @param buffMaterials: array list heroS auxiliary materials
   * request Create Token: 1: countHero; 3: category; isHeroS: 1
   */
  function fusion(
    uint256[] calldata mainMaterials,
    uint256[] calldata buffMaterials
  ) external canFusion(mainMaterials, buffMaterials) {
    uint256 rarityMain;
    uint256 rarityTarget;
    uint256[] memory dropRateOption = new uint256[](6);
    (rarityMain, rarityTarget, dropRateOption) = _calculateFusion(mainMaterials, buffMaterials);
    address to = msg.sender;

    //category = 3: use fusion.
    requestCreateToken(to, 1, BHeroDetails.ALL_RARITY, 3, 1, dropRateOption);

    //burn list hero
    bHeroToken.burn(mainMaterials);
    if (buffMaterials.length > 0) {
      bHeroToken.burn(buffMaterials);
    }

    emit Fusion(to, mainMaterials, buffMaterials, rarityMain, rarityTarget);
  }

  /**
   * @dev return rarityMain, rarityTarget, dropRateOption
   * percent get 2 decimals: ex: input 456 %  for 4.56%
   */

  function _calculateFusion(
    uint256[] calldata mainMaterials,
    uint256[] calldata buffMaterials
  ) internal view returns (uint256, uint256, uint256[] memory) {
    uint256 countMain = mainMaterials.length;
    uint256 rarityMain = _getRarityByHeroS(mainMaterials[0]);
    uint256 rarityTarget = rarityMain + 1;
    require(rarityTarget < 6, "Rarity target max is 5");
    uint256 percent;
    uint256 surplusPercent;
    uint256[] memory dropRateOption = new uint256[](6);
    if (countMain == 4) {
      dropRateOption[rarityTarget] = 10000;
    } else {
      percent += countMain * 25 * 100 + _getPercentBuffMaterials(rarityTarget, buffMaterials);
      if (percent > 10000) {
        percent = 10000;
      }
      surplusPercent = 100 * 100 - percent;
      dropRateOption[0] = surplusPercent;
      dropRateOption[rarityTarget] = percent;
    }
    return (rarityMain, rarityTarget, dropRateOption);
  }

  function _isSameRarity(uint256[] calldata listIdHero) internal view returns (bool) {
    uint256 rarityFirst = _getRarityByHeroS(listIdHero[0]);
    uint256 countHero = listIdHero.length;
    for (uint256 i = 1; i < countHero; i++) {
      uint256 rarity = _getRarityByHeroS(listIdHero[i]);
      if (rarityFirst != rarity) {
        return false;
      }
    }
    return true;
  }

  function _getRarityByHeroS(uint256 idHeroS) internal view returns (uint256) {
    uint256 detailHeroS = getTokenDetailByID(idHeroS);
    require(BHeroDetails.isHeroS(detailHeroS), "Not HeroS");
    uint256 rarity = BHeroDetails.decodeRarity(detailHeroS);
    return rarity;
  }

  function getRarityByHeroS(uint256 idHeroS) public view returns (uint256) {
    return _getRarityByHeroS(idHeroS);
  }

  function _getPercentBuffMaterials(
    uint256 rarityTarget,
    uint256[] calldata buffMaterials
  ) internal view returns (uint256) {
    uint256 countHero = buffMaterials.length;
    uint256 result;
    for (uint256 i = 0; i < countHero; i++) {
      uint256 rarity = _getRarityByHeroS(buffMaterials[i]);
      if (rarity >= rarityTarget) {
        //maximum is 25%
        result += 25 * 100;
      } else {
        uint256 x = rarityTarget - rarity;
        result += (25 * 100) / (4 ** (x - 1));
      }
    }
    return result;
  }

  function setBcoinToken(address value) external onlyRole(DESIGNER_ROLE) {
    bcoinToken = IERC20(value);
  }

  function setSenToken(address value) external onlyRole(DESIGNER_ROLE) {
    senToken = IERC20(value);
  }

  function withdraw() external onlyRole(WITHDRAWER_ROLE) {
    bcoinToken.transfer(msg.sender, bcoinToken.balanceOf(address(this)));
    senToken.transfer(msg.sender, senToken.balanceOf(address(this)));
  }

  // admin withdraw a custom token
  function withdrawCustomToken(address value) external onlyRole(WITHDRAWER_ROLE) {
    IERC20(value).transfer(msg.sender, IERC20(value).balanceOf(address(this)));
  }

  /*
  // Set the price of a specific packId
  function setBcoinRockPackPrice(uint256[] memory packPrices) external onlyRole(DESIGNER_ROLE) {
    bcoinRockPackPrices = packPrices;
  }

  function setSenRockPackPrice(uint256[] memory packPrices) external onlyRole(DESIGNER_ROLE) {
    senRockPackPrices = packPrices;
  }

  function setNumRockPacks(uint256[] memory _numRockPacks) external onlyRole(DESIGNER_ROLE) {
    numRockPacks = _numRockPacks;
  }

  function buyRockPack(uint256 coinType, uint256 packId) external {
    if (coinType == 0) {
      uint256 price = bcoinRockPackPrices[packId];
      require(price > 0, "This packId does not exist or has no price set");

      // Transfer BCOIN from the buyer to the contract owner
      bcoinToken.transferFrom(msg.sender, address(this), price);

      // Emit the purchase event
      // emit Purchase(msg.sender, packId, price);
    } else if (coinType == 1) {
      uint256 price = senRockPackPrices[packId];
      require(price > 0, "This packId does not exist or has no price set");

      // Transfer BCOIN from the buyer to the contract owner
      senToken.transferFrom(msg.sender, address(this), price);

      // Emit the purchase event
      // emit Purchase(msg.sender, packId, price);
    }

    userInfos[msg.sender].totalRock += numRockPacks[packId];
  }*/

  function dummyDeploy5() public view returns (uint256) {
    return 0;
  }
}
