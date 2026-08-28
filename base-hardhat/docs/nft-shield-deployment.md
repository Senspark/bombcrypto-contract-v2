# NFT Shield System — Deployment Guide (BSC + Polygon)

## Prerequisites
- Node.js v18+
- `npx hardhat` working in `base-hardhat/`
- Admin private key with `UPGRADER_ROLE` on both networks
- Backend signer wallet (new keypair for `shieldSigner`)

---

## Step 1: Generate Shield Signer Keypair

The shield signer is a backend-only wallet that signs unlock/disable messages. **This wallet never holds funds — it only signs EIP-191 messages.**

```bash
# Generate a new signer (store the private key securely)
node -e "const { Wallet } = require('ethers'); const w = Wallet.createRandom(); console.log('Address:', w.address); console.log('Private Key:', w.privateKey);"
```

Save the private key in your server environment as `NFT_SHIELD_SIGNER_PRIVATE_KEY`.

---

## Step 2: Deploy Contract Upgrade

### BSC Mainnet
```bash
cd base-hardhat
npx hardhat run scripts/upgrade-bhero.ts --network bsc
npx hardhat run scripts/upgrade-bhouse.ts --network bsc
```

### Polygon Mainnet
```bash
npx hardhat run scripts/upgrade-bhero.ts --network polygon
npx hardhat run scripts/upgrade-bhouse.ts --network polygon
```

> ⚠️ **IMPORTANT**: Since the contracts use UUPS upgradeable proxies, the proxy address stays the same. Only the implementation changes. Verify the new implementation on the block explorer after deployment.

---

## Step 3: Configure Shield Signer On-Chain

After the upgrade is deployed, set the `shieldSigner` address on both contracts and both networks:

```javascript
// Using Hardhat console or a script
const bhero = await ethers.getContractAt("BHeroToken", BHERO_PROXY_ADDRESS);
await bhero.setShieldSigner(SHIELD_SIGNER_ADDRESS);

const bhouse = await ethers.getContractAt("BHouseToken", BHOUSE_PROXY_ADDRESS);
await bhouse.setShieldSigner(SHIELD_SIGNER_ADDRESS);
```

Repeat for both BSC and Polygon.

---

## Step 4: Server Configuration

Add these environment variables to the game server (`bombcrypto-server-v2`):

```env
# Shield signer private key (signs unlock messages)
NFT_SHIELD_SIGNER_PRIVATE_KEY=0x...

# Enable shield feature (set to false to disable without redeploying)
NFT_SHIELD_ENABLED=true

# PIN attempt limits
NFT_SHIELD_MAX_ATTEMPTS=3
NFT_SHIELD_LOCKOUT_BASE_HOURS=24
```

---

## Step 5: Database Migration

Run the migration to create the `user_nft_shield` table:

```sql
CREATE TABLE IF NOT EXISTS user_nft_shield (
    id SERIAL PRIMARY KEY,
    wallet_address VARCHAR(42) NOT NULL UNIQUE,
    pin_hash VARCHAR(128) NOT NULL,
    pin_salt VARCHAR(64) NOT NULL,
    is_active BOOLEAN DEFAULT false,
    failed_attempts INT DEFAULT 0,
    lockout_until TIMESTAMP NULL,
    lockout_multiplier INT DEFAULT 1,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_shield_wallet ON user_nft_shield(wallet_address);
```

---

## Step 6: Client Update

The Unity client changes are compiled into the next build. Ensure the feature flag is enabled:

```json
// Server feature config
{
  "EnableNftShield": true
}
```

---

## Step 7: Marketplace Update

Deploy the updated `bombcrypto-market-v2` backend and frontend:

```bash
# Backend
cd bombcrypto-market-v2/backend
npm run build && npm run deploy

# Frontend
cd bombcrypto-market-v2/frontend
npm run build && npm run deploy
```

---

## Verification Checklist

| Check | Command / Action | Expected |
|-------|-----------------|----------|
| Contract upgraded | `bhero.shieldSigner()` | Returns signer address |
| Shield activatable | Call `activateShield()` from any wallet | `isShieldActive(wallet)` returns `true` |
| Transfer blocked | Try `transferFrom` on shielded wallet | Reverts with "NFT Shield: Token is locked" |
| Unlock works | `unlockTokensWithSignature()` with valid sig | Token unlocked, transfer succeeds |
| Emergency flow | `requestEmergencyDisable()` → wait 7 days → `executeEmergencyDisable()` | Shield disabled |
| PIN setup (client) | Open game → Inventory → Shield setup | 4-digit PIN dialog appears |
| Market badge | List a hero from shielded wallet | 🛡️ badge visible |
| Sell guard | Try to sell locked NFT | Error: "NFT is protected" |

---

## Rollback Plan

If issues are found post-deployment:

1. **Disable feature flag**: Set `EnableNftShield: false` on the server — hides all UI
2. **Emergency contract pause**: Call `pause()` on BHeroToken if critical vulnerability found
3. **Signer rotation**: Call `setShieldSigner(NEW_ADDRESS)` to rotate compromised signer

The shield system is additive — disabling it simply makes `isShieldActive` return `false` for all users, allowing normal transfers to resume.
