Deploy a smart contract using Hardhat
This tutorial describes how to deploy a sample smart contract on the Saigon testnet and interact with it using the Ronin app. Additionally, the tutorial describes how to verify a smart contract using the Ronin Sourcify service.

Prerequisites
A Hardhat project. If you are not familiar with Hardhat, follow the official Hardhat tutorial.
npm or yarn for package installation. This tutorial uses yarn.
A Ronin Wallet browser extension.
Steps
Step 1. Install hardhat-deploy
Start with installing the hardhat-deploy package. This package is required for deploying smart contracts on Ronin.

In your Hardhat project, install hardhat-deploy using the following command:
yarn add --dev hardhat-deploy

To enable hardhat-deploy, add the following line to your hardhat.config.js file:
require("hardhat-deploy");

Step 2. Set up the environment
To deploy your contract onto the Saigon testnet and then the Ronin mainnet, provide the network information to Hardhat.

In the hardhat.config.js file, add a networks object with the following code:

hardhat.config.js
module.exports = {
solidity: "0.8.28",
networks: {
ronin: {
chainId: 2020,
url: "https://api.roninchain.com/rpc",
},
saigon: {
chainId: 2021,
url: "https://saigon-testnet.roninchain.com/rpc",
},
},
};

Step 3. Set up a deployer account
To deploy the smart contract, you need a deployer account with some RON to cover transaction gas fees.

In the hardhat.config.js file, add a namedAccounts object with the following code:
hardhat.config.js
module.exports = {
solidity: "0.8.28",
networks: {
ronin: {
chainId: 2020,
url: "https://api.roninchain.com/rpc",
accounts:["0xYourPrivateKey"]
},
saigon: {
chainId: 2021,
url: "https://saigon-testnet.roninchain.com/rpc",
accounts:["0xYourPrivateKey"]
},
},
};

Retrieve the private key in your Ronin Wallet browser extension:
Open the extension, and at the top right corner, click the profile icon.
Click Manage. You'll see a list of your accounts.
Select the account from which you wish to deploy the contract, then click View private key, and then enter your password.
Copy replace 0xYourPrivateKey with your private key.
Top up your Saigon testnet deployer account with RON to cover the gas fees using the Ronin Faucet.
info
By default, the Saigon testnet network doesn't appear in Ronin Wallet. To make it visible, you need to enable it in the Ronin Wallet extension. Follow the steps in the Accessing Saigon Testnet guide.

Step 4. Write a deployment script
In your project's root directory, create a sub-directory for a deployment script:

mkdir deploy

Create a file called 1_deploy_token.js and paste the following code:

1_deploy_token.js
const func = async function (hre) {
const { deployments, getNamedAccounts } = hre;
const { deploy } = deployments;

const { deployer } = await getNamedAccounts();

await deploy("Token", {
from: deployer,
args: [],
log: true,
});
};
module.exports = func;
func.tags = ["Token"];

Step 5. Deploy the contract on the Saigon testnet
Now that you have set up the environment, you can deploy your smart contract on the Saigon testnet.

To deploy your contract, run the following command:

yarn hardhat deploy --network saigon

Setting the --gasprice flag explicitly is required to work around the issue with the provider used by Hardhat ignoring the gas price set in hardhat.config.js. Make sure that you installed the required hardhat-deploy package in Step 1.

You should see output with the deployed address similar to this:

deploying "Token" (tx: 0x6a3ecf86a07cbde9505bdfc233b9949a276ee54c04bc52269c161e9aad128d8b)...: deployed at 0x2D7b763d4A86dd105d8878f31993c7995e9261A1 with 686956 gas
✨  Done in 16.14s.


Copy the contract address. In the preceding example, our contract address is 0x2D7b763d4A86dd105d8878f31993c7995e9261A1.

Open the Saigon testnet explorer and paste your contract address in the search field.

To view your contract, select it in the list.


Step 6. Verify the contract using Ronin Sourcify
Although this step is optional, verifying your smart contract and publishing its source code can build trust for your app. Ronin uses the Sourcify service to make this task easier.

To publish the source code of your contract to Sourcify, run the following command:

yarn hardhat --network saigon sourcify --endpoint https://sourcify.roninchain.com/server

In the Saigon testnet explorer, search for your contract, then select the Contracts tab, and then notice the green checkmark. The checkmark indicates that your contract is successfully verified.


See also
Verify a smart contract
Testnet faucet