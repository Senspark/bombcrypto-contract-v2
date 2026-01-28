require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');
require("@nomicfoundation/hardhat-chai-matchers");
require("@nomicfoundation/hardhat-ledger");

const { privateKey, bscApiKey, polygonApiKey, oklinkApiKey } = require('./env.json');


module.exports = {
  solidity: {
    version:  "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 2000,
      }
    }
  },
  networks: {
    hardhat: {
      ledgerAccounts: [
        "0xD53b028d9b38A78564E058D9f033601234567890"
      ],
    },
    bsc: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      gasPrice: 20000000000,
      accounts: [privateKey]
    },
    bsctestnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      gasPrice: 20000000000,
      accounts: [privateKey]
    },
    polygon: {
      url: "https://polygon-rpc.com/",
      chainId: 137,
      gasPrice: 100000000000,
      accounts: [privateKey],
    },
    polygontestnet: {
      url: "https://go.getblock.io/5dad1b5c99234f9eae857fdd87a0627b",
      chainId: 80001,
      gasPrice: 20000000000,
      accounts: [privateKey]
    },
    polygonAmoy: {
      url: "https://rpc-amoy.polygon.technology/",
      chainId: 80002,
      gasPrice: 35000000000,
      accounts: [privateKey]
    }
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://bscscan.com/
    apiKey: {
      bsc: bscApiKey,
      bscTestnet: bscApiKey,
      polygon: polygonApiKey,
      polygonMumbai: polygonApiKey,
      polygonAmoy: polygonApiKey
    }
    , 
    customChains: [
      {
        network: "polygonAmoy",
        chainId: 80002,
        urls: {
          apiURL: "https://api-amoy.polygonscan.com/api",
          browserURL: "https://amoy.polygonscan.com/"
        }
      }
    ]
  }
};

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

task("sign", "Signs a message", async (_, hre) => {
  const message =
      "0x5417aa2a18a44da0675524453ff108c545382f0d7e26605c56bba41234567890";
  const account = "0xcA0F134d259cc80C1ac723ae2e90c11234567890";

  const signature = await hre.network.provider.request({
      method: "personal_sign",
      params: [
          "0x5417aa2a18a44da0675524453ff108c545382f0d7e26605c56bba41234567890",
          account,
      ],
  });

  console.log(
      "Signed message",
      message,
      "for Ledger account",
      account,
      "and got",
      signature
  );
});