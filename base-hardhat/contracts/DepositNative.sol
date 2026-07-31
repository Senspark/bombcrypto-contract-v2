// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

// Same-network native (BNB / POL) deposit + withdraw vault (UUPS proxy). Payout is capped by
// `allowedCumulative <= deposited[user]`, so the contract never trusts server arithmetic alone.
// Withdraw uses a signed cumulative amount (MAX-style), so replay protection is structural.
contract DepositNative is
  Initializable,
  AccessControlUpgradeable,
  ReentrancyGuardUpgradeable,
  UUPSUpgradeable
{
  using ECDSAUpgradeable for bytes32;

  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
  bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

  mapping(address => uint256) public deposited; // cumulative native wei in, only ever +=
  mapping(address => uint256) public withdrawn; // cumulative native wei out, only ever +=
  uint256 public totalDeposited;
  uint256 public totalWithdrawn;

  // Directional kill switches; default false (fail-safe OFF) after upgrade.
  bool public depositEnabled;
  bool public withdrawEnabled;

  event NativeDeposited(address indexed user, uint256 amount, uint256 depositedTotal);
  event NativeWithdrawn(
    address indexed user,
    uint256 amount,
    uint256 allowedCumulative,
    uint256 withdrawnTotal
  );
  event ManagerWithdrawn(address indexed to, uint256 amount);
  event NativeRescued(address indexed to, uint256 amount);
  event DepositEnabledChanged(bool enabled);
  event WithdrawEnabledChanged(bool enabled);

  function initialize() public initializer {
    __AccessControl_init();
    __ReentrancyGuard_init();
    __UUPSUpgradeable_init();

    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(UPGRADER_ROLE, msg.sender);
    _grantRole(MANAGER_ROLE, msg.sender);
    _grantRole(SIGNER_ROLE, msg.sender);
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

  // --- User flows ---

  function deposit() external payable {
    require(depositEnabled, "Deposit disabled");
    require(msg.value > 0, "Zero amount");

    deposited[msg.sender] += msg.value;
    totalDeposited += msg.value;

    emit NativeDeposited(msg.sender, msg.value, deposited[msg.sender]);
  }

  // User-relayed, withdraw-MAX: amount = allowedCumulative - withdrawn[user], so replay or a
  // stale cumulative both revert on their own.
  function withdraw(uint256 allowedCumulative, uint256 deadline, bytes calldata signature)
    external
    nonReentrant
  {
    require(withdrawEnabled, "Withdraw disabled");
    require(block.timestamp <= deadline, "Expired");

    address signer = _hashWithdraw(msg.sender, allowedCumulative, deadline).recover(signature);
    require(hasRole(SIGNER_ROLE, signer), "Bad signer");

    require(allowedCumulative <= deposited[msg.sender], "Exceeds deposit"); // structural cap
    uint256 amount = allowedCumulative - withdrawn[msg.sender];             // stale sig → underflow revert
    require(amount > 0, "Nothing to withdraw");                             // replay → revert

    withdrawn[msg.sender] += amount; // effects before interaction
    totalWithdrawn += amount;

    // .call, not .transfer, so contract-wallet recipients aren't gas-capped at 2300.
    (bool ok, ) = payable(msg.sender).call{value: amount}("");
    require(ok, "Native transfer failed");

    emit NativeWithdrawn(msg.sender, amount, allowedCumulative, withdrawn[msg.sender]);
  }

  // --- Admin ---

  function setDepositEnabled(bool enabled) external onlyRole(MANAGER_ROLE) {
    depositEnabled = enabled;
    emit DepositEnabledChanged(enabled);
  }

  function setWithdrawEnabled(bool enabled) external onlyRole(MANAGER_ROLE) {
    withdrawEnabled = enabled;
    emit WithdrawEnabledChanged(enabled);
  }

  // Profit extraction; unbounded on-chain, trusted to MANAGER_ROLE + the backend's own accounting.
  function managerWithdraw(address to, uint256 amount) external onlyRole(MANAGER_ROLE) nonReentrant {
    require(to != address(0), "Zero address");
    require(amount > 0, "Zero amount");

    (bool ok, ) = payable(to).call{value: amount}("");
    require(ok, "Native transfer failed");

    emit ManagerWithdrawn(to, amount);
  }

  // Liquidation escape hatch for retiring this proxy; not for routine ops.
  function rescueNative(address to) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
    require(to != address(0), "Zero address");
    uint256 bal = address(this).balance;
    require(bal > 0, "Nothing to rescue");

    (bool ok, ) = payable(to).call{value: bal}("");
    require(ok, "Native transfer failed");

    emit NativeRescued(to, bal);
  }

  // --- Internal ---

  // EIP-191 digest the backend signs off-chain; binds address(this) + chainid for domain separation.
  function _hashWithdraw(address user, uint256 allowedCumulative, uint256 deadline)
    private
    view
    returns (bytes32)
  {
    bytes32 raw = keccak256(
      abi.encodePacked(user, allowedCumulative, deadline, address(this), block.chainid)
    );
    return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", raw));
  }
}

// Deliberately no receive() / fallback(): a raw transfer would arrive without crediting deposited[user].
