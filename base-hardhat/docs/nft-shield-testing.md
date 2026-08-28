# NFT Shield System — Test Execution Guide

## For Senspark QA Team

This guide covers how to test the NFT Shield System across all layers: smart contract, game client, and marketplace.

---

## 1. Smart Contract Tests

### Prerequisites
```bash
cd bombcrypto-contract-v2/base-hardhat
npm install
```

### Run Tests
```bash
npx hardhat test test/BHeroShield.js
```

### What the tests cover

| Test Case | Description |
|-----------|-------------|
| `Shield activation` | Verifies `activateShield()` sets `isShieldActive` to true |
| `Transfer blocked` | Shielded wallet cannot transfer NFTs without unlocking |
| `Unlock with signature` | Backend-signed message unlocks specific token IDs |
| `Auto re-lock` | After transfer, token is automatically re-locked |
| `Emergency disable` | 7-day cooldown flow works correctly |
| `Cancel emergency` | Owner can cancel emergency disable before 7 days |
| `Nonce increment` | Each signature uses incremented nonce (replay protection) |
| `Bad signature rejected` | Invalid signatures are rejected |
| `Non-owner blocked` | Cannot unlock tokens you don't own |

### Expected Output
```
  BHero Shield System
    ✓ should allow activating shield
    ✓ should block transfer when shield is active
    ✓ should allow transfer after unlock with valid signature
    ✓ should auto re-lock token after transfer
    ✓ should support emergency disable after 7 days
    ✓ should reject emergency disable before 7 days
    ✓ should allow canceling emergency disable
    ✓ should increment nonce after each signature use
    ✓ should reject invalid signatures
    ✓ should reject unlock from non-owner
```

---

## 2. Server API Tests

### PIN Setup Flow
```
POST /api/nft-shield/setup
Body: { "pin": "1234" }
Headers: { "Authorization": "Bearer <JWT>" }

Expected: 200 OK, shield activated
```

### PIN Verification Flow
```
POST /api/nft-shield/verify
Body: { "pin": "1234", "tokenIds": [42, 99] }
Headers: { "Authorization": "Bearer <JWT>" }

Expected: 200 OK, returns { "signature": "0x...", "nonce": 0 }
```

### Lockout Test
```
POST /api/nft-shield/verify (wrong PIN x3)

Expected after 3 fails:
- 423 Locked
- Body: { "lockedUntil": "2026-04-28T01:51:00Z", "multiplier": 2 }
```

### Lockout Doubling
```
After first lockout expires:
- 3 more wrong attempts → locked for 48 hours (multiplier: 4)
- 3 more wrong attempts → locked for 96 hours (multiplier: 8)
```

---

## 3. Game Client Tests (Unity)

### Test Scenario 1: First-Time Shield Setup
1. Open game → Login
2. Go to Inventory
3. Look for 🛡️ Shield Setup button (appears if `EnableNftShield` is true)
4. Tap → `DialogSecuritySetup` opens
5. Enter 4-digit PIN → Confirm
6. Shield status should show as active

### Test Scenario 2: Lock Badges
1. After activating shield, go to Inventory
2. Heroes with active stake should show lock badge
3. Tap a hero → lock icon visible on `InventoryHeroL`

### Test Scenario 3: Bulk Lock
1. Go to Inventory
2. Find "Lock All" button
3. Tap → All owned tokens should be locked
4. Verify via contract: `isTokenUnlocked(tokenId)` returns `false`

### Test Scenario 4: Transfer Attempt
1. Try to send a hero to another wallet (outside game)
2. Expected: Transaction reverts with "NFT Shield: Token is locked"
3. Go back to game, unlock the hero with PIN
4. Try transfer again → succeeds

---

## 4. Marketplace Tests

### Test Scenario 1: Shield Badge Display
1. Activate shield on wallet A
2. List a hero for sale from wallet A
3. Go to marketplace → hero should show 🛡️ badge

### Test Scenario 2: Sell Guard
1. With shield active and tokens locked
2. Go to Inventory → Try to sell a hero
3. Expected: Error modal: "🛡️ NFT is protected! Please open the BombCrypto game and unlock this NFT using your PIN before selling."
4. Go to game → Unlock the token with PIN
5. Return to marketplace → Sell succeeds

### Test Scenario 3: Buy (no impact)
1. Buyer purchases a shielded hero from wallet A
2. Expected: Transaction succeeds (seller already unlocked token to list it)
3. After purchase: token is auto re-locked in buyer's wallet (if buyer has shield active)

---

## 5. Edge Cases to Verify

| Edge Case | Expected Behavior |
|-----------|-------------------|
| Shield inactive + transfer | Normal transfer, no PIN required |
| Shield active + unlock + transfer + re-check | Token auto re-locked after transfer |
| Emergency disable during lockout | Emergency timer starts regardless of PIN lockout |
| Contract paused + shield active | Pause blocks ALL transfers (higher priority) |
| Multiple tokens unlock at once | Single signature can unlock batch of token IDs |
| Signer rotation mid-flight | Old signatures become invalid after `setShieldSigner` |

---

## Network-Specific Testing

### BSC Testnet
- Contract addresses: (to be provided post-deploy)
- Explorer: https://testnet.bscscan.com

### Polygon Amoy (Testnet)
- Contract addresses: (to be provided post-deploy)
- Explorer: https://amoy.polygonscan.com

### Production Verification
After mainnet deployment, verify using the block explorer:
1. Read `shieldSigner()` → returns expected address
2. Read `isShieldActive(testWallet)` → returns expected boolean
3. Verify implementation contract is verified on explorer
