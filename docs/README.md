# ✍️ BombCrypto Contracts Documentation

> "Where Bomber Heroes are born, traded, and staked."

[![License: ISC](https://img.shields.io/badge/License-ISC-blue.svg)](https://opensource.org/licenses/ISC)
[![Docs](https://img.shields.io/badge/docs-up%20to%20date-brightgreen)](./)

Welcome to the official documentation for the **BombCrypto Smart Contracts**. This repository contains the logic powering the BombCrypto ecosystem on the **Base** and **Ronin** networks.

## 📚 Documentation Map

### 🏗️ Architecture
Understand the high-level design and critical data flows.
- [System Context & Containers](./architecture/system-context.md) 🗺️
- [Critical Flows (Minting, Trading, Staking)](./architecture/flows.md) 🔄

### 📘 Manuals
Guides for different stakeholders.
- [User Guide](./manuals/user-guide.md) 🎮 - Learn about Tokens, Heroes, and Marketplace.
- [Developer Guide](./manuals/developer-guide.md) 👨‍💻 - Setup, Deployment, and Verification.

### ⚙️ Reference
Deep dive into the code.
- [Contract Reference](./reference/contracts.md) 📝 - API details for core contracts.

## 🚀 Quick Start (Devs)

```bash
git clone <repo>
npm install
cd ron-base && cp .env.example .env
# Fill .env
npx hardhat compile
```

## ❓ What is BombCrypto?
BombCrypto is a Play-to-Earn game where players manage a team of bomb heroes of cyborgs programmed to search for BCOIN and fight monsters. This repository hosts the immutable rules of that universe.
