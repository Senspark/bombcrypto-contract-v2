// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

contract SenPolygonPresale is Initializable, AccessControlUpgradeable, UUPSUpgradeable {

  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  bytes32 public constant DESIGNER_ROLE = keccak256("DESIGNER_ROLE");
  bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");

  IERC20 public bcoinToken;
  IERC20 public senToken;
  IERC20 public usdtToken;

  bool public isUserWithdraw;
  bool public isPause;

  uint256 public amountBcoinDeposit;
  uint256 public amountSenDeposit;

  mapping(address => uint256) public bcoinBalances;
  mapping(address => uint256) public senBalances;
  mapping(address => uint256) public usdtBalances;

  uint256 public minUSDT;
  uint256 public maxUSDT;

  function initialize(IERC20 bcoinToken_, IERC20 senToken_, IERC20 usdtToken_) public initializer {
    __AccessControl_init();
    __UUPSUpgradeable_init();
    bcoinToken = bcoinToken_;
    senToken = senToken_;
    usdtToken = usdtToken_;
    
    isUserWithdraw = false;
    isPause = false;

    amountBcoinDeposit = 1500000000000000000000;
    amountSenDeposit = 5000000000000000000000;

    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(UPGRADER_ROLE, msg.sender);
    _setupRole(DESIGNER_ROLE, msg.sender);
    _setupRole(WITHDRAWER_ROLE, msg.sender);

    minUSDT = 20000000000000000000;
    maxUSDT = 200000000000000000000;

  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

  function supportsInterface(bytes4 interfaceId) public view override(AccessControlUpgradeable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function depositBcoin(uint256 amount) external {
    require(!isPause, "Not Pause");
    require(amount >= minUSDT, "Amount must be greater than 20");
    require(usdtBalances[msg.sender] + amount <= maxUSDT, "Total must be less than 200");
    usdtToken.transferFrom(msg.sender, address(this), amount);
    usdtBalances[msg.sender] += amount;
    if (bcoinBalances[msg.sender] == 0) {
      bcoinToken.transferFrom(msg.sender, address(this), amountBcoinDeposit);
      bcoinBalances[msg.sender] = amountBcoinDeposit;
    }
  }


  function depositSen(uint256 amount) external {
    require(!isPause, "Not Pause");
    require(amount >= minUSDT, "Amount must be greater than 20");
    require(usdtBalances[msg.sender] + amount <= maxUSDT, "Total must be less than 200");
    usdtToken.transferFrom(msg.sender, address(this), amount);
    usdtBalances[msg.sender] += amount;
    if (senBalances[msg.sender] == 0) {
      senToken.transferFrom(msg.sender, address(this), amountSenDeposit);
      senBalances[msg.sender] = amountSenDeposit;
    }
  }

  function withdraw() external {
    require(isUserWithdraw, "Allow withdraw");
    require(bcoinBalances[msg.sender] > 0 || senBalances[msg.sender] > 0, "balances[msg.sender] > 0");
    if (bcoinBalances[msg.sender] > 0) {
      bcoinToken.transfer(msg.sender, bcoinBalances[msg.sender]);
      bcoinBalances[msg.sender] = 0;
    }
    if (senBalances[msg.sender] > 0) {
      senToken.transfer(msg.sender, senBalances[msg.sender]);
      senBalances[msg.sender] = 0;
    }
  }

  function setAmountBcoinDeposit(uint256 amountBcoinDeposit_) external onlyRole(DESIGNER_ROLE) {
    amountBcoinDeposit = amountBcoinDeposit_;
  }

  function setAmountSenDeposit(uint256 amountSenDeposit_) external onlyRole(DESIGNER_ROLE) {
    amountSenDeposit = amountSenDeposit_;
  }

  // Admin function to withdraw
  function adminWithdraw(address receiver, uint256 amount) external onlyRole(WITHDRAWER_ROLE) {
    require(amount > 0, "Amount must be greater than 0");

    // Transfer tokens from this contract to the receiver
    usdtToken.transfer(receiver, amount);
  }

  // Admin function to set pause
  function setIsUserWithdraw(bool isUserWithdraw_) external onlyRole(DESIGNER_ROLE) {
    isUserWithdraw = isUserWithdraw_;
  }

  // Admin function to set pause
  function setIsPause(bool isPause_) external onlyRole(DESIGNER_ROLE) {
    isPause = isPause_;
  }

  function setBcoinAddr(IERC20 bcoinToken_) external onlyRole(DESIGNER_ROLE) {
    bcoinToken = bcoinToken_;
  }

  function setSenAddr(IERC20 senToken_) external onlyRole(DESIGNER_ROLE) {
    senToken = senToken_;
  }

  function setUsdtAddr(IERC20 usdtToken_) external onlyRole(DESIGNER_ROLE) {
    usdtToken = usdtToken_;
  }

  function setMinUSDT(uint256 min_) external onlyRole(DESIGNER_ROLE) {
    minUSDT = min_;
  }

  function setMaxUSDT(uint256 max_) external onlyRole(DESIGNER_ROLE) {
    maxUSDT = max_;
  }
}
