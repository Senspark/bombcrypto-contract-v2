require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");
require("@openzeppelin/hardhat-upgrades");
require("hardhat-deploy");
require("dotenv").config();

const {chains} = require("./chains.config");

const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x0000000000000000000000000000000000000000000000000000000000000000";
const ETHERSCAN_MULTICHAIN_API_KEY = process.env.ETHERSCAN_MULTICHAIN_API_KEY || "";

const networks = {};
Object.entries(chains).forEach(([name, config]) => {
    networks[name] = {
        url: config.rpcUrl,
        chainId: config.chainId,
        accounts: [PRIVATE_KEY]
    };

    // Add special configuration for Viction networks
    if (name.includes('viction')) {
        networks[name].gas = 8000000; // 8M gas limit
        networks[name].gasPrice = 250000000; // 0.25 gwei
        networks[name].timeout = 60000; // 60 second timeout
        networks[name].httpHeaders = {
            "Content-Type": "application/json"
        };
    }
});

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: {
        version: "0.8.24",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200
            }
        }
    },
    networks: {
        hardhat: {
            chainId: 31337
        },
        ...networks
    },
    namedAccounts: {
        deployer: {
            default: 0
        }
    },
    etherscan: {
        apiKey: ETHERSCAN_MULTICHAIN_API_KEY,
        customChains: [
            {
                network: "base-mainnet",
                chainId: 8453,
                urls: {
                    apiURL: "https://api.basescan.org/api",
                    browserURL: "https://basescan.org"
                }
            },
            {
                network: "base-testnet",
                chainId: 84532,
                urls: {
                    apiURL: "https://api-sepolia.basescan.org/api",
                    browserURL: "https://sepolia.basescan.org"
                }
            },
            {
                network: "ronin-mainnet",
                chainId: 2020,
                urls: {
                    apiURL: "https://sourcify.roninchain.com/server",
                    browserURL: "https://app.roninchain.com"
                }
            },
            {
                network: "ronin-testnet",
                chainId: 2021,
                urls: {
                    apiURL: "https://sourcify.roninchain.com/server",
                    browserURL: "https://saigon-app.roninchain.com"
                }
            },
            {
                network: "viction-mainnet",
                chainId: 88,
                urls: {
                    apiURL: "https://www.vicscan.xyz/api/contract/hardhat/verify",
                    browserURL: "https://vicscan.xyz"
                }
            },
            {
                network: "viction-testnet",
                chainId: 89,
                urls: {
                    apiURL: "https://scan-api-testnet.viction.xyz/api/contract/hardhat/verify",
                    browserURL: "https://testnet.vicscan.xyz"
                }
            }
        ]
    },
    sourcify: {
        enabled: false,
        apiUrl: "https://sourcify.roninchain.com/server",
    }
};