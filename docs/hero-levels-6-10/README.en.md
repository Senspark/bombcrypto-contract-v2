# Hero upgrade levels 6-10

[Português](README.pt.md) · [Tiếng Việt](README.vi.md)

Raises the hero level cap from 5 to 10. Levels 6-10 alternate between energy and power, and
charge BCOIN + SEN + the chain's native coin instead of native only.

> **Testnet only.** Every contract here refuses any chain that is not BSC testnet (97) or
> Polygon Amoy (80002). The faucet token has an open, permissionless `mint`.

## How the new levels work

Each upgrade burns one material hero and raises the base hero by one level.

| Level | Gains | Power total | Stamina total |
|------:|-------|------------:|--------------:|
| 1-5   | (existing behaviour) | 0 1 2 3 5 | 0 0 0 0 0 |
| 6     | +1 energy | 5 | 1 |
| 7     | +1 power  | 6 | 1 |
| 8     | +1 energy | 6 | 2 |
| 9     | +1 power  | 7 | 2 |
| 10    | +1 power and +1 energy | 8 | 3 |

Both tables store the **cumulative total at that level**, not the per-upgrade delta. Power
repeats at levels 6 and 8 (5,5 and 6,6) because those levels grant stamina instead.

One stamina point is worth 50 energy (`HeroHelper.ENERGY_PER_STAMINA`), so a rarity-9 hero goes
from 30 stamina / 1500 energy at level 5 to 33 / 1650 at level 10.

### Material rule

Below level 5 the material must be the **same level** as the base hero — unchanged. From level 5
onward the material is always a **level 5** hero, so reaching level 10 does not require an
exponentially deeper chain of upgrades.

### Why the bonus is never written on-chain

`BHeroDetails` packs stamina and bombPower into **5 bits each**, so 31 is the ceiling. A rarity-9
hero already has 30 of each, and the level bonus would push power to 38 and stamina to 33.

This is not a new risk introduced by levels 6-10 — the ceiling is already exceeded today, since a
level-5 rarity-9 hero reads as 35 power. It works because the bonus is **computed at runtime by the
server** and never stored. The contract only mutates bits 45-49 (level); it never touches the stat
fields. Keep it that way.

### Token burn

25% of the BCOIN and SEN charged is burned; the remaining 75% stays in the contract for
`WITHDRAWER_ROLE`. The native coin is not burned, and legacy levels (1-4) burn nothing because they
charge no tokens.

The burn destination depends on `burnSink`:

- `burnSink == address(0)` (default): a **real burn** via `burnFrom` — `totalSupply` drops and the
  log records `Transfer` to `0x0`.
- `burnSink != address(0)`: a plain transfer to that address. Needed for tokens that do not expose
  `burnFrom`, because OpenZeppelin's `_transfer` **reverts** when the destination is the zero
  address — there is no way to "transfer to 0x0".

`scripts/upgrade-bhero-upgrade-v2.js` detects `burnFrom` by looking for selector `79cc6790` in the
deployed bytecode and sets `burnSink` accordingly. Getting this wrong makes **every** token-charging
upgrade revert.

### The native coin is not hardcoded

The contract charges `msg.value`, so "native" is BNB on BSC and POL on Polygon with no branching in
the code. The only currency-specific value is `nativeRate`, set per chain in
`NATIVE_RATE_BY_CHAIN`, calibrated so the upgrade costs the same in USD on both chains.

## How to apply

> Commands below that use `hardhat.local.config.js`, `deploy-testnet-stack.js`,
> `upgrade-tokens-to-burnable.js`, `build-server.sh` or `deploy-amoy.sh` belong to the **local
> testnet stack**, not to the feature. They live in separate `chore(testnet)` commits. On an
> official deployment, use that project's own Hardhat config, real token contracts and deployment
> pipeline; only the database migrations, the extension rebuild and the contract deploy/upgrade
> steps are part of the feature itself.

### 1. Database

```bash
psql -U postgres -d bombcrypto -f server/db/migrations/20260910_120100_extend_hero_upgrade_power_to_level_10.sql
psql -U postgres -d bombcrypto -f server/db/migrations/20260910_120000_add_hero_upgrade_stamina.sql
```

Verify — both must return 10 rows:

```sql
SELECT rare, datas FROM config_hero_upgrade_power   ORDER BY rare;  -- [0,1,2,3,5,5,6,6,7,8]
SELECT rare, datas FROM config_hero_upgrade_stamina ORDER BY rare;  -- [0,0,0,0,0,1,1,2,2,3]
```

The config is read into memory at startup, so **restart the game server after** running these, not
before.

### 2. Server extension

```bash
./build-server.sh
```

Publish the JAR to the directory the container actually mounts. The upstream `server/run.sh` copies
to `server/deploy/extensions_volume`, which is what the upstream compose file mounts; the local
stack mounts `server/deploy/SmartFoxServer_2X` instead. Publishing to the wrong one leaves the
container running the old JAR from the image, and the symptom is
`Request handler not found: 'GET_HERO_UPGRADE_STAMINA_V2'` with the client hanging on the matching
sync step.

`build-server.sh` compares the JAR size inside the container against the local build and fails loudly
if they differ.

### 3. Contracts

```bash
cd repos/bombcrypto-contract-v2/base-hardhat
npx hardhat --config hardhat.local.config.js test test/BHeroUpgradeV2.js

# New deployment
DEPLOYER_KEY=0x... npx hardhat --config hardhat.local.config.js --network <net> run scripts/deploy-testnet-stack.js
DEPLOYER_KEY=0x... HERO_TOKEN=0x... HERO_DESIGN=0x... BCOIN_TOKEN=0x... SEN_TOKEN=0x... \
  npx hardhat --config hardhat.local.config.js --network <net> run scripts/deploy-bhero-upgrade-v2.js

# Upgrading an existing proxy
DEPLOYER_KEY=0x... PROXY=0x... npx hardhat --config hardhat.local.config.js --network <net> run scripts/upgrade-bhero-upgrade-v2.js
```

`initialize` does not run again on a proxy upgrade, so any new field with a default has to be set
explicitly — that is what the upgrade script does for `burnRateBps` and `burnSink`.

For the full Polygon Amoy stack: `./deploy-amoy.sh` (needs POL for gas).

### Switching the test tokens to burnable

Only needed where the deployed tokens predate the burn feature:

```bash
DEPLOYER_KEY=0x... PROXY=0x... HOLDERS=0xa,0xb \
  npx hardhat --config hardhat.local.config.js --network <net> run scripts/upgrade-tokens-to-burnable.js
```

This deploys new tokens, re-mints each holder's balance, repoints the proxy and enables the real
burn. **Token addresses change**, so `addresses.ts`, `BscAddress.ts`, the wallets' token lists and
the ERC20 allowances all need updating afterwards.

### 4. Client

The level cap lives in `UpgradeHeroLevelPolygon.MaxLevel` and must mirror
`BHeroDesign.getMaxLevel()`. All levels route through `BHeroUpgradeV2`, including 1-4, which the
contract prices as native-only — the old path read from the production `BHeroS`, which does not
exist in the test stack.

## Storage layout

`BHeroUpgradeV2` is a UUPS proxy. Two fields were appended after `nativeRate` (`burnRateBps`,
`burnSink`) and `__gap` was reduced from 40 to 38 to keep the total footprint constant. Keep that
invariant on any future upgrade.

## Files

| Area | Path |
|---|---|
| Contract | `base-hardhat/contracts/BHeroUpgradeV2.sol` |
| Test token | `base-hardhat/contracts/TestnetFaucetToken.sol` |
| Tests | `base-hardhat/test/BHeroUpgradeV2.js` |
| Stamina config | `.../data/manager/hero/HeroUpgradeStaminaManager.kt` |
| Stat totals | `.../data/manager/hero/HeroHelper.kt` |
| Migrations | `server/db/migrations/20260910_*.sql` |
| Upgrade dialog | `Assets/Scripts/Game/Dialog/UpgradeHeroLevelPolygon.cs` |
