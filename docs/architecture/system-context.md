# Architecture: System Context & Containers

## C4 Level 1: System Context

This diagram illustrates the high-level context of the BombCrypto Contract system.

```mermaid
C4Context
    title System Context Diagram for BombCrypto Contracts

    Person(user, "User", "A player or investor in the BombCrypto ecosystem.")
    System(bombcrypto, "BombCrypto Contracts", "The collection of smart contracts governing tokens, NFTs, marketplace, and staking.")
    System_Ext(blockchain, "Blockchain Network", "EVM-compatible blockchain (Base, Ronin) where contracts are deployed.")

    Rel(user, bombcrypto, "Interacts with", "Wallet/Web3")
    Rel(bombcrypto, blockchain, "Resides on", "EVM")
```

## C4 Level 2: Container Diagram

This diagram zooms into the BombCrypto system to show the key smart contract containers and their relationships.

```mermaid
C4Container
    title Container Diagram for BombCrypto Contracts

    Person(user, "User", "Player/Investor")

    Container_Boundary(c1, "BombCrypto System") {
        Container(token, "BCoinToken", "ERC20", "The native currency (BCOIN).")
        Container(nft, "BHeroToken", "ERC721", "The NFT Heroes (BHERO).")
        Container(market, "BHeroMarket", "Contract", "Marketplace for trading Heroes.")
        Container(stake, "BCoinStake2024", "Contract", "Staking mechanism for BCOIN.")
        Container(design, "BHeroDesign", "Contract", "Logic provider for Hero generation/randomization.")
        Container(bridge, "NativeTokenDepositor", "Contract", "Handles native token deposits (Ronin).")
    }

    Rel(user, token, "Transfers/Approves")
    Rel(user, nft, "Transfers/Approves")
    Rel(user, market, "Trades on")
    Rel(user, stake, "Stakes in")
    Rel(user, bridge, "Deposits to")

    Rel(market, token, "Uses for payment")
    Rel(market, nft, "Transfers on sale")
    Rel(nft, design, "Uses for logic")
    Rel(stake, token, "Locks/Rewards")
```
