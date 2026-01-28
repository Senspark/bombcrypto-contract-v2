// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

contract BBridge is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
  mapping(address => uint256) public balances;
  address public token;
  uint256 public taxPercentage;
  uint256 public taxAmount; // tax is counted from source
  bool public isPause; //pause deposit method
  bool public isPauseBridge; //pause bridge method
  uint256 public taxAmountV2; // total accrued tax is counted from target chain

  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  bytes32 public constant DESIGNER_ROLE = keccak256("DESIGNER_ROLE");
  bytes32 public constant BRIDGER_ROLE = keccak256("BRIDGER_ROLE");
  bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");

  mapping(address => bool) public whiteList;

  // Represents an paid out receipt
  struct PaidReceipt {
    // the user who paid out
    address user;
    // the amount to paid out in wei (already deducted the tax)
    uint256 amount;
    // tax amount in wei
    uint256 taxAmount;
    // the token to paid out
    address tokenAddress;
    // block number of the Deposit tx in chainA
    uint256 blockNumber;
  }
  // store all paid receipts
  mapping(string => PaidReceipt) public paidReceipts;

  event Deposit(address indexed user, uint256 amount, address indexed token, uint256 taxPercentage);  
  //event Withdraw(address indexed user, uint256 amount, address indexed token);
  event BridgeFrom(address indexed user, uint256 amount, address indexed token, uint256 taxPercentage);
  event BridgeTo(address indexed user, uint256 amount, address indexed token, uint256 taxPercentage);

  function initialize(address token_) public initializer {
    __AccessControl_init();
    __UUPSUpgradeable_init();

    token = token_;
    taxPercentage = 10;
    taxAmount = 0;
    taxAmountV2 = 0;
    isPause = false;
    isPauseBridge = false;

    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(UPGRADER_ROLE, msg.sender);
    _grantRole(DESIGNER_ROLE, msg.sender);
    _grantRole(BRIDGER_ROLE, msg.sender);
    _grantRole(WITHDRAWER_ROLE, msg.sender);
    _grantRole(PAUSER_ROLE, msg.sender);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(AccessControlUpgradeable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function setToken(address token_) external onlyRole(DESIGNER_ROLE) {
    token = token_;
  }

  function setTaxPercentage(uint256 taxPercentage_) external onlyRole(DESIGNER_ROLE) {
    require(taxPercentage_ > 0, "Tax percentage must be greater than 0");
    require(taxPercentage_ < 100, "Tax percentage must be less than 100");
    taxPercentage = taxPercentage_;
  }

// Admin function to set Tax Amount
  function setTaxAmount(uint256 taxAmount_) external onlyRole(DESIGNER_ROLE) {
    taxAmount = taxAmount_;
  }

  // Admin function to set Tax Amount
  function setTaxAmountV2(uint256 taxAmount_) external onlyRole(DESIGNER_ROLE) {
    taxAmountV2 = taxAmount_;
  }

  function setWhitelistAddress(address addr, bool allow) external onlyRole(DESIGNER_ROLE) {
    whiteList[addr] = allow;
  }

// Admin funciton to set the bridge isPauseDeposit
  function setPauseDeposit(bool isPauseDeposit_) external onlyRole(PAUSER_ROLE) {
    isPause = isPauseDeposit_;
  }

  function setPauseBridge(bool isPauseBridge_) external onlyRole(PAUSER_ROLE) {
    isPauseBridge = isPauseBridge_;
  }

  function deposit(uint256 amount) external {
    require(amount >= 200000000000000000000, "Amount must be greater than 200");
    require(amount <= 50000000000000000000000, "Amount must be less than 50000");
    if (isPause) {
      if (!whiteList[msg.sender])
        require(!isPause, "Deposit needs not pause");
    }

    // Transfer tokens from the user to this contract
    IERC20(token).transferFrom(msg.sender, address(this), amount);

    // Update user's balance after tax
    balances[msg.sender] += (amount*(100-taxPercentage)/100);
    
    // Update tax Amount
    // taxAmount +=  (amount*taxPercentage/100); // use V2

    emit Deposit(msg.sender, amount, token, taxPercentage);
  }

  // function withdraw(uint256 amount) external onlyRole(WITHDRAWER_ROLE) {
  //   require(amount > 0, "Amount must be greater than 0");
  //   require(balances[msg.sender] >= amount, "Insufficient balance");

  //   // Transfer tokens from this contract to the user
  //   IERC20(token).transfer(msg.sender, amount);

  //   // Update user's balance
  //   balances[msg.sender] -= amount;

  //   emit Withdraw(msg.sender, amount, token);
  // }

  // Admin function to withdraw fees or maintain the bridge
  function adminWithdraw(address receiver, uint256 amount) external onlyRole(WITHDRAWER_ROLE) {
    require(amount > 0, "Amount must be greater than 0");

    // Transfer tokens from this contract to the receiver
    IERC20(token).transfer(receiver, amount);
  }

// Admin function to withdraw tax
  function taxWithdraw(address receiver, uint256 amount) external onlyRole(WITHDRAWER_ROLE) {
    require(amount > 0, "Amount must be greater than 0");

    taxAmount -= amount;
    IERC20(token).transfer(receiver, amount);
  }

  // Admin function to withdraw tax V2
  function taxWithdrawV2(address receiver, uint256 amount) external onlyRole(WITHDRAWER_ROLE) {
    require(amount > 0, "Amount must be greater than 0");

    taxAmountV2 -= amount;
    IERC20(token).transfer(receiver, amount);
  }

  function getPossisbleWithdrawingAmount(address user) public view returns (uint256) {
    return balances[user];
  }

  function bridgeFrom(address user) external onlyRole(BRIDGER_ROLE) {
    require(balances[user] > 0, "Amount must be greater than 0");
    require(!isPauseBridge, "Bridge needs not pause");

    uint256 amount = balances[user];

    // update user's balance that bridged from the chain that is the other side
    balances[user] = 0;

    emit BridgeFrom(user, amount, token, taxPercentage);
  }

  function bridgeTo(address user, uint256 amount) external onlyRole(BRIDGER_ROLE) {
    require(amount > 0, "Amount must be greater than 0");
    require(!isPauseBridge, "Bridge needs not pause");

    // Transfer tokens from this contract to the user
    IERC20(token).transfer(user, amount);

    taxAmountV2 += ((amount*taxPercentage)/(100-taxPercentage));

    emit BridgeTo(user, amount, token, taxPercentage);
  }

  // @dev Bridge from chainA to chainB
    // @param user - the user wallet to pay out
    // @param amount - the amount to pay out
    // @param txHash - the txHash of the Deposit tx in chainA
    // @param blockNumber - the block number of the Deposit tx in chainA
  function bridgeToV2(address user, uint256 amount, string memory txHash, uint256 blockNumber) external onlyRole(BRIDGER_ROLE) {
    require(amount > 0, "Amount must be greater than 0");
    require(!isPauseBridge, "Bridge needs not pause");

    // check if already paid
    PaidReceipt storage __receipt = paidReceipts[txHash];
    require(!_isPaid(__receipt), "already paid");
    // Not paid yet? Let's pay out
    uint256 tax = ((amount*taxPercentage)/(100));

    require(IERC20(token).balanceOf(address(this)) > amount, "Not enough balance to paid out");
    // Create a receipt to avoid reentrancy attack
    PaidReceipt memory receipt = PaidReceipt(
        user,
        amount,
        tax,
        token,
        blockNumber
    );
    // save it
    paidReceipts[txHash] = receipt;

    // Transfer tokens from this contract to the user
    require(IERC20(token).transfer(user, amount), "transfer token failed");

    taxAmountV2 += ((amount*taxPercentage)/(100-taxPercentage));
    emit BridgeTo(user, amount, token, taxPercentage);
  }

    // @dev Returns true if the Receipt existed (already paid)
    // @param _receipt - receipt to check.
    function _isPaid(PaidReceipt storage _receipt) internal view returns (bool) {
        return (_receipt.blockNumber > 0);
    }

    // @dev Return the receipt for the given txHash
    // @param txHash - the txHash to get the receipt for.
    function getPaidReceipt(string memory txHash) public view returns (PaidReceipt memory) {
        return paidReceipts[txHash];
    }

    function dummyDeploy() public view returns (uint256) {
      return 0;
    }
}
