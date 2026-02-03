# Developer Guide

This guide covers the setup, development, and deployment process for the BombCrypto smart contracts.

## Prerequisites

- **Node.js**: v14+ (v18 recommended)
- **Hardhat**: `npm install --save-dev hardhat`
- **Wallet**: Ronin Wallet / Metamask

## Installation

1. Clone the repository:
   ```bash
   git clone <repo-url>
   cd bombcrypto-contract
   ```

2. Install dependencies:
   ```bash
   # In root
   npm install

   # In sub-projects if needed
   cd ron-base && npm install
   cd ../base-hardhat && npm install
   ```

3. Environment Setup:
   Copy `.env.example` to `.env` in `ron-base` and `base-hardhat` and populate your private keys.
   ```bash
   cp ron-base/.env.example ron-base/.env
   ```

## Folder Structure

- **`base-hardhat/`**: Contains core game contracts (BHero, Market, Staking). Deployed on Base/Viction chains.
- **`ron-base/`**: Contains deployment scripts and specific contracts (`NativeTokenDepositor`) for the Ronin network.
- **`docs/`**: Documentation (you are here).

## Deployment & Verification

### Ronin Network

Using `ron-base`:

```bash
cd ron-base

# Deploy to Testnet (Saigon)
npx hardhat deploy --network ronin-testnet

# Verify on Testnet
npx hardhat --network ronin-testnet sourcify --endpoint https://sourcify.roninchain.com/server

# Deploy to Mainnet
npx hardhat deploy --network ronin-mainnet

# Verify on Mainnet
npx hardhat --network ronin-mainnet sourcify --endpoint https://sourcify.roninchain.com/server
```

### Base Network

Using `ron-base` (or `base-hardhat` depending on configuration):

```bash
cd ron-base

# Deploy to Base Testnet
npx hardhat deploy --network base-testnet

# Verify on Base Testnet
npx hardhat --network base-testnet etherscan-verify

# Deploy to Base Mainnet
npx hardhat deploy --network base-mainnet

# Verify on Base Mainnet
npx hardhat --network base-mainnet etherscan-verify
```

### Viction Network

```bash
cd ron-base

# Deploy
npx hardhat deploy --network viction-mainnet

# Verify
npx hardhat --network viction-mainnet etherscan-verify --api-key tomoscan2023 --api-url https://www.vicscan.xyz/api/contract/hardhat/verify
```

## Running Tests

(Note: Tests are currently located in `base-hardhat/test`)

```bash
cd base-hardhat
npx hardhat test
```
