# Native Token Depositor - Upgradeable Contract

Contract để deposit RON cho RONIN, ETH cho BASE.

## Setup
```bash
# Cài đặt thư viện lần đầu (nếu chưa cài)
npm install

cp .env.example .env # Sau đó điền private key vào file .env
```

## Deployment

Support sẵn script cho các network: `ronin-mainnet, ronin-testnet, base-mainnet, base-testnet`

### Đối với Ronin (Production):
```bash
# Deploy thay đổi
npx hardhat deploy --network ronin-mainnet
# Verify
npx hardhat --network ronin-mainnet sourcify --endpoint https://sourcify.roninchain.com/server
```

### Đối với Base (Main net):
```bash
# Deploy thay đổi
npx hardhat deploy --network base-mainnet
# Verify
npx hardhat --network base-mainnet etherscan-verify
```

### Đối với Viction (Main net):
```bash
# Deploy thay đổi
npx hardhat deploy --network viction-mainnet
# Verify
npx hardhat --network viction-mainnet etherscan-verify --api-key tomoscan2023 --api-url https://www.vicscan.xyz/api/contract/hardhat/verify
```

### Testnet:
```bash
# Ronin:
npx hardhat deploy --network ronin-testnet
npx hardhat --network ronin-testnet sourcify --endpoint https://sourcify.roninchain.com/server

# Base
npx hardhat deploy --network base-testnet
npx hardhat --network base-testnet etherscan-verify

# Viction
npx hardhat deploy --network viction-testnet
npx hardhat --network viction-testnet etherscan-verify --api-key tomoscan2023 --api-url https://scan-api-testnet.viction.xyz/api/contract/hardhat/verify
```

Test rpc:
```bash
# Base Sepolia
curl https://sepolia.base.org/ \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"method":"eth_blockNumber","params":[],"id":1,"jsonrpc":"2.0"}'
  
# Viction Testnet
curl https://rpc-testnet.viction.xyz \
-X POST \
-H "Content-Type: application/json" \
--data '{"method":"eth_blockNumber","params":[],"id":1,"jsonrpc":"2.0"}'
```