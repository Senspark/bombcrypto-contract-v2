// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract SenStake is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using SafeMathUpgradeable for uint256;

  event Stake(address indexed user, uint256 amount);
  event Withdraw(address indexed user, uint256 amount);
  event GetReward(address indexed user, uint256 reward);
  event RestakeReward(address indexed user, uint256 reward);
  event Unstake(address indexed user, uint256 amount);

  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

  IERC20Upgradeable public rewardsToken;
  IERC20Upgradeable public stakingToken;

  uint256 private totalStake; // ?
  uint256 public lastUpdateTime; // ?
  uint256 public rewardPerTokenStored; //?

  struct Staker {
    uint256 rewards;
    uint256 balances;
    uint256 timeStake; // time that user starts staking
    uint256 userRewardPerTokenPaid;
  }
  mapping(address => Staker) stakers;

  //time start smartcontract
  uint256 private timeStart;

  //unlock timeline
  uint256[] private tokenUnlock;

  //withdraw fee percent
  uint256[] private widthdrawFee;

  function initialize(IERC20Upgradeable _stakingToken, IERC20Upgradeable _rewardsToken) public initializer {
    __AccessControl_init();
    __UUPSUpgradeable_init();

    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(UPGRADER_ROLE, msg.sender);

    stakingToken = _stakingToken;
    rewardsToken = _rewardsToken;
    timeStart = block.timestamp;

    tokenUnlock = 
    [
      300000, 300000, 300000, 300000, 300000, 300000, 
      300000, 300000, 300000, 300000, 300000, 300000,
      300000, 300000, 300000, 300000, 300000, 300000,
      300000, 300000, 300000, 300000, 300000, 300000  
    ];

    widthdrawFee = [15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0];
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

  function updateTokenUnlock(uint256[] memory _newTokenUnlock) external onlyRole(DEFAULT_ADMIN_ROLE) {
    tokenUnlock = _newTokenUnlock;
  }

  function setTokenStaking(address[] memory _stakeVsReward) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(_stakeVsReward.length == 2, "Set value invalid");
    stakingToken = IERC20Upgradeable(_stakeVsReward[0]);
    rewardsToken = IERC20Upgradeable(_stakeVsReward[1]);
  }

  modifier updateReward(address _account) {
    rewardPerTokenStored = rewardPerToken();
    lastUpdateTime = block.timestamp;
    stakers[_account].rewards = earned(_account);
    stakers[_account].userRewardPerTokenPaid = rewardPerTokenStored;
    _;
  }

  function stake(uint256 _amount) external updateReward(msg.sender) {
    if (stakers[msg.sender].balances == 0) {
      require(_amount >= 200 * 1e18, "Amount < 200");
    }
    require(_amount <= stakingToken.balanceOf(msg.sender), "Invalid amount");
    uint256 allowance = stakingToken.allowance(msg.sender, address(this));
    require(allowance >= _amount, "Check the token allowance");

    //set time first stake
    if (stakers[msg.sender].balances == 0) {
      stakers[msg.sender].timeStake = block.timestamp;
    }
    stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
    totalStake += _amount;
    stakers[msg.sender].balances += _amount;
    emit Stake(msg.sender, _amount);
  }

  function withdraw(uint256 _amount) external updateReward(msg.sender) {
    require(_amount <= stakers[msg.sender].balances, "Amount <= balance");
    require(_amount <= stakingToken.balanceOf(address(this)), "Not enough tokens in the reserve");

    //check withdraw fee day
    uint256 fee = getWithdrawFeeByUser(msg.sender);
    uint256 amount_fee = (_amount * fee) / 100;
    uint256 amount_withdraw = _amount - amount_fee;

    stakingToken.safeTransfer(msg.sender, amount_withdraw);

    totalStake -= _amount;
    stakers[msg.sender].balances -= _amount;

    emit Withdraw(msg.sender, _amount);
  }

  function withdrawToken() external onlyRole(DEFAULT_ADMIN_ROLE) {
    stakingToken.safeTransfer(msg.sender, stakingToken.balanceOf(address(this)));
  }

  function unstake() external updateReward(msg.sender) {
    uint256 fee = getMyFee(msg.sender);
    uint256 reward = stakers[msg.sender].rewards;

    uint256 totalWithdraw = (stakers[msg.sender].balances - fee) + reward;
    require(totalWithdraw <= stakingToken.balanceOf(address(this)), "Not enough tokens in the reserve");
    totalStake -= stakers[msg.sender].balances;

    stakingToken.safeTransfer(msg.sender, totalWithdraw);

    stakers[msg.sender].rewards = 0;
    stakers[msg.sender].balances = 0;

    emit Unstake(msg.sender, totalWithdraw);
  }

  function getReward() external updateReward(msg.sender) {
    uint256 reward = stakers[msg.sender].rewards;
    rewardsToken.safeTransfer(msg.sender, reward);
    stakers[msg.sender].rewards = 0;
    emit GetReward(msg.sender, reward);
  }

  function restakeReward() external updateReward(msg.sender) {
    uint256 reward = stakers[msg.sender].rewards;
    stakers[msg.sender].rewards = 0;
    stakers[msg.sender].balances += reward;
    totalStake += reward;
    emit RestakeReward(msg.sender, reward);
  }

  function rewardPerToken() public view returns (uint256) {
    if (totalStake == 0) {
      return rewardPerTokenStored;
    }
    return rewardPerTokenStored + ((block.timestamp - lastUpdateTime) * rewardPerTokenBySecond());
  }

  function rewardPerTokenBySecond() public view returns (uint256) {
    if (totalStake == 0) {
      return 0;
    }
    return (getTokenUnlock() * 1e18) / totalStake / 30 / 24 / 3600;
  }

  function rewardPerTokenByDay() public view returns (uint256) {
    if (totalStake == 0) {
      return 0;
    }
    return (getTokenUnlock() * 1e18) / totalStake / 30;
  }

  function earned(address _account) public view returns (uint256) {
    return
      ((stakers[_account].balances * (rewardPerToken() - stakers[_account].userRewardPerTokenPaid)) / 1e18) +
      stakers[_account].rewards;
  }

  function getTokenUnlock() public view returns (uint256) {
    uint256 currentTime = block.timestamp;
    uint256 dayStaked = (currentTime - timeStart) / 3600 / 24;

    //get index array token unlock from month staked
    uint256 index = dayStaked / 30;
    if (index < tokenUnlock.length) {
      return tokenUnlock[index] * 1e18;
    }
    return 0;
  }

  function getWithdrawFeeByUser(address _account) public view returns (uint256) {
    uint256 currentTime = block.timestamp;
    uint256 dayStaked = (currentTime - stakers[_account].timeStake) / 3600 / 24;

    //get index array withdraw fee from day staked
    uint256 index = 0;
    if (dayStaked > 0) {
      index = dayStaked - 1;
    }
    if (index < widthdrawFee.length) {
      return widthdrawFee[index];
    }
    return 0;
  }

  //return view
  //api return value
  function getTotalStaked() public view returns (uint256) {
    return totalStake;
  }

  function getDailyRewards() public view returns (uint256) {
    return (rewardPerTokenByDay() * totalStake) / 1e18;
  }

  function getPercentAPR() public view returns (uint256) {
    return rewardPerTokenByDay() * 365 * 100;
  }

  function getMyStaked(address _account) public view returns (uint256) {
    return stakers[_account].balances;
  }

  function getMyProfit(address _account) public view returns (uint256) {
    return (stakers[_account].balances * rewardPerTokenByDay()) / 1e18;
  }

  function getMyFee(address _account) public view returns (uint256) {
    uint256 fee = getWithdrawFeeByUser(_account);
    uint256 amount_fee = (stakers[_account].balances * fee) / 100;
    return amount_fee;
  }

  function getMyTimeStake(address _account) public view returns (uint256) {
    return stakers[_account].timeStake;
  }

  function getTimeStart() public view returns (uint256) {
    return timeStart;
  }
}
