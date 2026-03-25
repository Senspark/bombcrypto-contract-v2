# Contract Reference

This document provides a technical reference for the core smart contracts in the BombCrypto ecosystem.

## 🪙 BCoinToken
**Location**: `base-hardhat/contracts/BCoinToken.sol`
**Type**: ERC20

The native token of the ecosystem.

| Function | Description | Access |
| :--- | :--- | :--- |
| `burn(uint256 amount)` | Burns tokens from the sender's balance. | Public |

---

## 🦸 BHeroToken
**Location**: `base-hardhat/contracts/BHeroToken.sol`
**Type**: ERC721 Upgradeable

The main NFT contract for Heroes. Handles minting, fusing, and attribute randomization.

| Function | Description | Access |
| :--- | :--- | :--- |
| `createTokenRequest(...)` | Requests to mint new heroes. Requires target block wait. | MINTER_ROLE |
| `processTokenRequests()` | Finalizes minting (or fusion) after target block passed. | Public |
| `randomizeAbilities(id)` | Requests randomization of hero abilities. | Owner |
| `processRandomizeAbilities(id)` | Applies random stats based on block hash. | Owner |
| `fusion(...)` | (Internal logic) Fuses heroes to create higher rarity ones. | Logic via Design |

---

## 🏪 BHeroMarket
**Location**: `base-hardhat/contracts/BHeroMarket.sol`
**Type**: Marketplace

Facilitates trading of BHero NFTs.

| Function | Description | Access |
| :--- | :--- | :--- |
| `createOrder(tokenId, price, token)` | Lists a hero for sale. | Owner |
| `buy(tokenId, price)` | Purchases a listed hero. | Public |
| `cancelOrder(tokenId)` | Cancels a listing. | Owner/Admin |
| `withdraw()` | Withdraws accumulated fees. | WITHDRAWER_ROLE |

---

## 🏦 BCoinStake2024
**Location**: `base-hardhat/contracts/BCoinStake2024.sol`
**Type**: Staking

Allows users to stake BCOIN and earn rewards.

| Function | Description | Access |
| :--- | :--- | :--- |
| `stake(amount)` | Stakes BCOIN into the pool. | Public |
| `withdraw(amount)` | Withdraws staked BCOIN (subject to fees). | Public |
| `getReward()` | Claims pending rewards. | Public |
| `restakeReward()` | Compounds rewards back into stake. | Public |
| `earned(account)` | View pending rewards for an account. | Public (View) |

---

## 🌉 NativeTokenDepositor
**Location**: `ron-base/contracts/NativeTokenDepositor.sol`
**Type**: Utility

Simple deposit contract for native tokens (e.g., RON).

| Function | Description | Access |
| :--- | :--- | :--- |
| `deposit(invoice)` | Deposits native token with an invoice string. | Public (Payable) |
| `withdraw()` | Owner withdraws all funds. | Owner |
