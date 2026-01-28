// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

// 1st level: stake coin to get shield for BHero: L -> S
// 2nd level: stake minimum coin to be qualified for TH 1.1
// Higher level: stake coin to make hero powerful in aspect of mining coin, compete to other heroes in rank for TH 2.0

// V1: only BCOIN
// V2: 
//     + Expands to other tokens 
//     + Apply weighted average for the stake time of previous stake and current stake

contract BHeroStake is Initializable, AccessControlUpgradeable, UUPSUpgradeable {

  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  bytes32 public constant DESIGNER_ROLE = keccak256("DESIGNER_ROLE");
  bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");

  IERC20 public coinToken;
  ERC721Upgradeable public nftToken;

  struct Staker {
    uint256 balance;
    uint256 timeStake; // time that hero starts staking
  }
  
  //stake coin to empower heroes
  // bcoin
  mapping(uint256 => Staker) public heroStake;

  //withdraw fee percent
  uint256[] public withdrawFee;

  //amount
  uint256 public withdrawFeeAmount;

  mapping(address => mapping(uint256 => Staker)) public heroStakeV2;
  mapping(address => uint256) public withdrawFeeAmountsV2;

  event BalanceChanged(address token, uint256 id, uint256 amount);

  function initialize(IERC20 coinToken_, ERC721Upgradeable nftToken_) public initializer {
    __AccessControl_init();
    __UUPSUpgradeable_init();
    coinToken = coinToken_;
    nftToken = nftToken_;

    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(UPGRADER_ROLE, msg.sender);
    _setupRole(DESIGNER_ROLE, msg.sender);
    _setupRole(WITHDRAWER_ROLE, msg.sender);

    withdrawFee = [30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0];
    withdrawFeeAmount = 0;
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

  function supportsInterface(bytes4 interfaceId) public view override(AccessControlUpgradeable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function setCoinToken(address value) external onlyRole(DESIGNER_ROLE) {
    coinToken = IERC20(value);
  }

  function setNFTToken(address value) external onlyRole(DESIGNER_ROLE) {
    nftToken = ERC721Upgradeable(value);
  }

  function depositCoinIntoHeroId(uint256 id, uint256 amount) external onlyRole(DESIGNER_ROLE) {
    require(nftToken.ownerOf(id) == msg.sender, "Must be owner of hero");
    require(amount>0, "Amount > 0");
    coinToken.transferFrom(msg.sender, address(this), amount);
    if (heroStake[id].balance == 0) { //a solution for time stake has done in V2
      heroStake[id].timeStake = block.timestamp;
    }
    heroStake[id].balance += amount;
  }

  function withdrawCoinFromHeroId(uint256 id, uint256 amount) external onlyRole(DESIGNER_ROLE) {
    require(nftToken.ownerOf(id) == msg.sender, "Must be owner of hero");
    require(amount > 0, "Amount > 0");
    require(amount <= heroStake[id].balance, "Amount <= heroStake[id].balance");
    
    //check withdraw fee day
    uint256 fee = getWithdrawFeeByHeroId(id);
    uint256 amount_fee = (amount * fee) / 100;
    uint256 amount_withdraw = amount - amount_fee;

    withdrawFeeAmount += amount_fee;

    coinToken.transfer(msg.sender, amount_withdraw);
    heroStake[id].balance -= amount;
  }

  function getCoinBalancesByHeroId(uint256 id) public view returns (uint256) {
    return heroStake[id].balance;
  }

  function setWithdrawFee(uint256[] memory _withdrawFee) external onlyRole(DESIGNER_ROLE) {
    withdrawFee = _withdrawFee;
  }

  function getWithdrawFeeByHeroId(uint256 id) public view returns (uint256) {
    uint256 currentTime = block.timestamp;
    uint256 dayStaked = (currentTime - heroStake[id].timeStake) / 3600 / 24;

    //get index array withdraw fee from day staked
    uint256 index = 0;
    if (dayStaked > 0) {
      index = dayStaked - 1;
    }
    if (index < withdrawFee.length) {
      return withdrawFee[index];
    }
    return 0;
  }

  // Admin function to withdraw fee 
  function withdrawUnstakeFee(address receiver, uint256 amount) external onlyRole(WITHDRAWER_ROLE) {
    require(amount > 0, "Amount must be greater than 0");

    withdrawFeeAmount -= amount;
    coinToken.transfer(receiver, amount);
  }

  // Bắt đầu các hàm của Hero Stake V2

  function depositV2(address token, uint256 id, uint256 amount) external {
    require(nftToken.ownerOf(id) == msg.sender, "Must be owner of hero");
    require(amount > 0, "Amount > 0");
    IERC20(token).transferFrom(msg.sender, address(this), amount); 
    if (((token != address(coinToken)) && (heroStakeV2[token][id].balance == 0)) ||
        ((token == address(coinToken)) && (heroStakeV2[token][id].balance == 0) && (heroStake[id].balance == 0))) { 
      // Trường hợp hero chưa có stake lần nào (cả V1 và V2). 
      // Nếu token khác BCOIN và Balance V2 == 0 hoặc 
      // Nếu token là BCOIN và Balance V2 == 0 và Balance V1 == 0 thì chắc chắn chưa stake lần nào

      // đặt time là lần đầu tiên stake
      heroStakeV2[token][id].timeStake = block.timestamp;
    } else {
      // trường hợp hero stake lần tiếp theo, đã có balance và time stake lần trước
      
      if (token == address(coinToken) && heroStake[id].balance > 0) {     
        // Trường hợp hero đã có stake ở V1 và tiếp tục stake ở V2
      
        // chuyển balance từ V1 sang V2
        heroStakeV2[token][id].balance = heroStake[id].balance;
        heroStake[id].balance = 0;

        // chuyển time stake từ V1 sang V2
        heroStakeV2[token][id].timeStake = heroStake[id].timeStake;
      }

      // tính lại time stake bằng công thức weighted average dựa trên số lượng token và thời gian mỗi lần stake
      // weightedAverage(prevTime, prevAmount, curTime, curAmount);
      uint256 currentTime = block.timestamp;
      uint256 t1 = currentTime-heroStakeV2[token][id].timeStake; //khoảng thời gian của lần stake trước
      uint256 a1 = heroStakeV2[token][id].balance; // số lượng token lần stake trước
      uint256 t2 = 0; // khoảng thời gian lần stake này
      uint256 a2 = amount; // số lượng token lần stake này
      uint256 twa = weightedAverage(t1, a1, t2, a2); // khoảng thời gian trung bình có trọng số của 2 lần stake
      
      heroStakeV2[token][id].timeStake = currentTime - twa;
    }

    heroStakeV2[token][id].balance += amount;

    emit BalanceChanged(token, id, amount);
  }

  // Formula is the following: weighted average = Σwx / Σw 
  function weightedAverage(uint256 x1, uint256 w1, uint256 x2, uint256 w2) internal pure returns (uint256) {
    return (x1*w1+x2*w2)/(w1+w2);
  }

  function withdrawV2(address token, uint256 id, uint256 amount) external {
    require(nftToken.ownerOf(id) == msg.sender, "Must be owner of hero");
    require(amount > 0, "Amount > 0");
    
    if (token == address(coinToken) && heroStake[id].balance > 0) {     
        // Trường hợp hero đã có stake ở V1 và tiếp tục stake ở V2
      
        // chuyển balance từ V1 sang V2
        heroStakeV2[token][id].balance = heroStake[id].balance;
        heroStake[id].balance = 0;

        // chuyển time stake từ V1 sang V2
        heroStakeV2[token][id].timeStake = heroStake[id].timeStake;
    }

    require(amount <= heroStakeV2[token][id].balance, "Amount <= heroStake balance");
  
    //check withdraw fee day
    uint256 fee = getWithdrawFeeV2(token, id);
    uint256 amount_fee = (amount * fee) / 100;
    uint256 amount_withdraw = amount - amount_fee;

    withdrawFeeAmountsV2[token] += amount_fee;

    IERC20(token).transfer(msg.sender, amount_withdraw);

    heroStakeV2[token][id].balance -= amount;

    emit BalanceChanged(token, id, amount);
  }

  function getCoinBalanceV2(address token, uint256 id) public view returns (uint256) {
    // kiểm tra trong trường hợp chưa chuyển được dữ liệu từ V1 sang V2 (chưa gọi lần nào deposit hay withdraw V2)
    if (token == address(coinToken)) {
      return heroStake[id].balance + heroStakeV2[token][id].balance;
    } else return heroStakeV2[token][id].balance;
  }

  function getTimeStakeV2(address token, uint256 id) public view returns (uint256) {
    if (token == address(coinToken) && heroStake[id].balance > 0) {
      return heroStake[id].timeStake;
    } else return heroStakeV2[token][id].timeStake;
  }

  function getWithdrawFeeV2(address token, uint256 id) public view returns (uint256) {
    uint256 currentTime = block.timestamp;
    uint256 dayStaked;

    // kiểm tra trong trường hợp chưa chuyển được dữ liệu từ V1 sang V2 (chưa gọi lần nào deposit hay withdraw V2)
    if (token == address(coinToken) && heroStake[id].balance != 0) {     
      dayStaked = (currentTime - heroStake[id].timeStake) / 3600 / 24;
    } else {
      dayStaked = (currentTime - heroStakeV2[token][id].timeStake) / 3600 / 24;
    }

    //get index array withdraw fee from day staked
    uint256 index = 0;
    if (dayStaked > 0) {
      index = dayStaked - 1;
    }
    if (index < withdrawFee.length) {
      return withdrawFee[index];
    }
    return 0;
  }

  function withdrawUnstakeFeeV2(address token, address receiver, uint256 amount) external onlyRole(WITHDRAWER_ROLE) {
    require(amount > 0, "Amount must be greater than 0");

    withdrawFeeAmountsV2[token] -= amount;
    IERC20(token).transfer(receiver, amount);
  }

  function dummyDeploy() public view returns (uint256) {
     return 0;
  }
}
