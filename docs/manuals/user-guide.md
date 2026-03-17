# User Guide

Welcome to the BombCrypto Ecosystem. This guide explains the core components and how to interact with them.

## 🪙 BCOIN Token

**BCOIN** is the native currency of the BombCrypto universe.
- **Symbol**: BCOIN
- **Type**: BEP20 / ERC20
- **Use Cases**:
  - Buying Heroes (BHERO).
  - Upgrading Heroes.
  - Staking for rewards.
  - Marketplace currency.

## 🦸 BHERO NFTs

**BHERO** are the NFTs used in the BombCrypto game. Each hero has unique stats and rarity.

### Getting a Hero
1. **Minting**: You can mint new heroes using BCOIN.
2. **Marketplace**: You can buy existing heroes from other players.

### Fusion
You can fuse heroes to potentially get a higher rarity hero. This burns the used heroes.

### Randomization
Newly minted heroes often need their abilities "revealed". This is a two-step process:
1. **Request Randomization**: Initiates the request.
2. **Process**: After a few blocks, the random values are generated based on block hashes.

## 🏪 Marketplace

The **BHeroMarket** allows players to trade BHERO NFTs trustlessly.

- **Buying**: Pay BCOIN (or other supported tokens) to purchase a listed Hero.
- **Selling**: List your Hero for a specific price. The Hero stays in the contract (or escrow) until sold or cancelled.
- **Fees**: A small tax is applied to sales, which goes back to the ecosystem.

## 🏦 Staking

Holders of BCOIN can stake their tokens to earn more BCOIN.

- **Stake**: Lock your BCOIN in the staking contract.
- **Rewards**: Rewards accrue over time based on the pool's emission rate.
- **Withdraw**: You can withdraw your principal and rewards. *Note: Early withdrawal fees may apply.*
