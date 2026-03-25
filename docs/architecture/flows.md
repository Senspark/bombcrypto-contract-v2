# Architecture: Critical Flows

This document details the sequence of operations for critical business logic within the BombCrypto ecosystem.

## 1. Hero Minting & Randomization

The process of creating a new Hero involves a request-response pattern to ensure randomness (or pseudo-randomness based on block hash).

```mermaid
sequenceDiagram
    participant User
    participant BHeroToken
    participant BHeroDesign
    participant Blockchain

    User->>BHeroToken: createTokenRequest(count, rarity, details)
    activate BHeroToken
    BHeroToken->>BHeroToken: Store Request & Emit TokenCreateRequested
    deactivate BHeroToken

    Note over User, Blockchain: Wait for Target Block

    User->>BHeroToken: processTokenRequests()
    activate BHeroToken
    BHeroToken->>BHeroDesign: createTokens(tokenId, amount, details)
    activate BHeroDesign
    BHeroDesign-->>BHeroToken: Returns Token Details (Attributes)
    deactivate BHeroDesign

    loop For each Hero
        BHeroToken->>BHeroToken: _safeMint(User, tokenId)
    end

    BHeroToken-->>User: Emit TokenCreated / Fusion Events
    deactivate BHeroToken
```

## 2. Marketplace: Buying a Hero

Buying a Hero on the marketplace requires prior approval of the payment token (BCOIN) and the NFT (by the seller).

```mermaid
sequenceDiagram
    participant Buyer
    participant Seller
    participant BHeroMarket
    participant BCoinToken
    participant BHeroToken

    Note over Seller, BHeroMarket: Seller must Approve BHeroMarket for NFT
    Seller->>BHeroMarket: createOrder(tokenId, price, tokenAddress)
    BHeroMarket->>BHeroToken: Transfer NFT to Market (or escrow check)
    Note right of BHeroMarket: Order Created

    Note over Buyer, BCoinToken: Buyer must Approve BHeroMarket for BCOIN
    Buyer->>BHeroMarket: buy(tokenId, price)
    activate BHeroMarket

    BHeroMarket->>BCoinToken: transferFrom(Buyer, Seller, price - tax)
    BHeroMarket->>BCoinToken: transferFrom(Buyer, Market, tax)
    BHeroMarket->>BHeroToken: transferFrom(Market, Buyer, tokenId)

    BHeroMarket-->>Buyer: Order Fulfilled
    deactivate BHeroMarket
```

## 3. Staking BCOIN

Users stake BCOIN to earn rewards over time.

```mermaid
sequenceDiagram
    participant User
    participant BCoinStake2024
    participant BCoinToken

    Note over User, BCoinToken: User Approves Stake Contract
    User->>BCoinStake2024: stake(amount)
    activate BCoinStake2024

    BCoinStake2024->>BCoinToken: transferFrom(User, Contract, amount)
    BCoinStake2024->>BCoinStake2024: Update User Balance & Time
    BCoinStake2024-->>User: Emit Stake Event
    deactivate BCoinStake2024

    Note right of User: Time Passes...

    User->>BCoinStake2024: getReward()
    activate BCoinStake2024
    BCoinStake2024->>BCoinStake2024: Calculate Earned
    BCoinStake2024->>BCoinToken: transfer(User, reward)
    deactivate BCoinStake2024
```
