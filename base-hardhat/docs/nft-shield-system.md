# NFT Shield System — Technical Specification

## Overview

The NFT Shield System introduces a non-custodial protection layer for BombCrypto's `BHeroToken` and `BHouseToken` contracts. It is an **OPT-IN** security feature that intercepts the standard `_transfer` hooks of ERC-721 to ensure that protected assets cannot be moved without explicitly authorizing the transfer via an off-chain PIN/Signature process or initiating a delayed emergency unlock sequence.

This is critical to protecting player assets from zero-day wallet drains and fishing attacks. **If activated by the user**, it requires authentication via the game client to lift the shield before assets can be transferred on-chain. If the user does not activate the shield, the contract maintains its original behavior.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    PLAYER WALLET                         │
│  activateShield() → isShieldActive[wallet] = true       │
└──────────────┬──────────────────────────────────────────┘
               │
    ┌──────────▼──────────┐
    │   GAME CLIENT       │
    │  (Unity / C#)       │
    │                     │
    │  DialogSecuritySetup│ ← First-time PIN registration
    │  DialogPinInput     │ ← PIN input for unlock/sell
    │  ISecurityManager   │ ← Service interface
    │  InventoryHeroS/L   │ ← Lock badge display
    └──────────┬──────────┘
               │ PIN + token IDs
    ┌──────────▼──────────┐
    │   GAME SERVER       │
    │  (Java / Handlers)  │
    │                     │
    │  NFTShieldManager   │ ← PIN hash/verify, lockout logic
    │  user_nft_shield    │ ← Database table
    │  Signer wallet      │ ← Signs EIP-191 messages
    └──────────┬──────────┘
               │ Signature
    ┌──────────▼──────────┐
    │   SMART CONTRACT    │
    │  (Solidity / EVM)   │
    │                     │
    │  _transfer override │ ← Blocks if shield active + token locked
    │  unlockTokensWithSig│ ← Verifies signature, unlocks tokens
    │  Emergency flow     │ ← 7-day self-service recovery
    └─────────────────────┘
```

---

## Features

1. **Global Shield Toggle**: Users activate protection across their wallet using `activateShield()`.
2. **Transfer Interceptor**: `_transfer` override blocks moves if shield is active and token is locked.
3. **Hybrid Cryptographic Unlocking**: Backend-signed EIP-191 messages unlock specific token IDs.
4. **Emergency Cooldown**: 7-day self-service recovery via `requestEmergencyDisable()` + `executeEmergencyDisable()`.
5. **Auto Re-Lock**: Tokens are automatically re-locked after transfer to protect new owners.
6. **PIN Lockout**: Server enforces 3-attempt limit with exponential doubling (24h → 48h → 96h...).

---

## Smart Contract Details

### New Storage Variables (appended to end of contract)
```solidity
address public shieldSigner;
mapping(address => bool) public isShieldActive;
mapping(uint256 => bool) public isTokenUnlocked;
mapping(address => uint256) public shieldNonce;
mapping(address => uint256) public emergencyUnlockStart;
```

### Transfer Interceptor
```solidity
function _transfer(address from, address to, uint256 tokenId) internal override {
    if (from != address(0) && isShieldActive[from]) {
        require(isTokenUnlocked[tokenId], "NFT Shield: Token is locked. Unlock it in-game.");
    }
    if (isTokenUnlocked[tokenId]) {
        isTokenUnlocked[tokenId] = false; // Auto re-lock
    }
    ERC721Upgradeable._transfer(from, to, tokenId);
}
```

### Signature Validation
```solidity
function _verifySignature(bytes32 messageHash, bytes calldata signature) internal view returns (bool) {
    bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    return signtureERC721.checkMessageSignature(ethSignedMessageHash, signature) == shieldSigner
        && shieldSigner != address(0);
}
```

### Bytecode Optimization
- Static-length revert strings ("Bad sig", "Bad shield state")
- Signature hashing on backend, contract validates packed encoding
- Hardhat optimizer: 200 runs for size reduction
- Stayed within 24KB EIP-170 Spurious Dragon limit

### Upgradability
UUPS proxy pattern preserved. New storage variables appended after existing contract storage — no slot collisions.

---

## Server Integration

### Database Schema
```sql
CREATE TABLE user_nft_shield (
    id SERIAL PRIMARY KEY,
    wallet_address VARCHAR(42) UNIQUE NOT NULL,
    pin_hash VARCHAR(128) NOT NULL,
    pin_salt VARCHAR(64) NOT NULL,
    is_active BOOLEAN DEFAULT false,
    failed_attempts INT DEFAULT 0,
    lockout_until TIMESTAMP NULL,
    lockout_multiplier INT DEFAULT 1,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

### Lockout Logic
| Attempt Block | Wrong PINs | Lockout Duration |
|---------------|-----------|-----------------|
| 1st           | 3         | 24 hours        |
| 2nd           | 3         | 48 hours        |
| 3rd           | 3         | 96 hours        |
| Nth           | 3         | 24 × 2^(N-1) hours |

### Server Handlers
- `SetupNftShieldPinHandler` — First-time PIN registration
- `VerifyNftShieldPinHandler` — PIN verification + lockout enforcement
- `GenerateNftShieldSignatureHandler` — Signs unlock message after PIN verified
- `GetNftShieldStatusHandler` — Returns shield status + lockout info

---

## Client Integration (Unity)

### Service Layer
- `ISecurityManager` — Interface for PIN operations
- `SecurityManager` — Implementation coordinating with server
- `IFeatureManager.EnableNftShield` — Feature gate flag

### UI Components
- `DialogSecuritySetup` — 4-digit PIN setup (first time)
- `DialogPinInput` — PIN verification dialog (before transfers/sales)
- `InventoryHeroS` / `InventoryHeroL` — Lock badge visibility
- `BLInventoryController` — Bulk lock button

---

## Marketplace Integration

### Backend Changes
- `HeroRepr` / `HeroTxRepr` — Added `isShielded?: boolean` field
- `hero-subscriber.ts` — Queries `isShieldActive(seller)` on CreateOrder events

### Frontend Changes
- `smc.tsx` — `isShieldActive()` + `isTokenUnlocked()` on-chain reads
- `inventory-bhero.tsx` — Sell guard (blocks sell if shield active + token locked)
- All card components — 🛡️ badge display for shielded NFTs

---

## Networks

Applies to both:
- **BSC Mainnet** (Chain ID: 56)
- **Polygon Mainnet** (Chain ID: 137)

Same contract logic, same signer, independent deployments.

---

## Related Documentation
- [Deployment Guide](nft-shield-deployment.md)
- [Test Execution Guide](nft-shield-testing.md)
