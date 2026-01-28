// const { ethers, upgrades } = require("hardhat");


const hre = require("hardhat");

// const { LedgerSigner } = require("@ethersproject/hardware-wallets"); 
// const { LedgerSigner } = require("@ethersproject/hardware-wallets");


// async function main() {
//     const ledger = new LedgerSigner(hre.ethers.provider);
//     const Melk = await hre.ethers.getContractFactory("BCoinToken");
//     let contractFactory = await Melk.connect(ledger)
//     const melk = await contractFactory.deploy();
//     await melk.deployed();
// }

async function main() {
//   const ledger = await new LedgerSigner(ethers.contractFactory.signer.provider, "hid", "m/44'/60'/0'/0");

  // === Test Ledger ===
  
  // const ledger = new LedgerSigner(hre.ethers.provider);
  // const Melk = await hre.ethers.getContractFactory("BCoinToken");
  // let contractFactory = await Melk.connect(ledger)
  // const melk = await contractFactory.deploy();
  // await melk.deployed();

  // ===

  // === BCoinToken ===
  // const [deployer] = await ethers.getSigners("0xD53b028d9b38A78564E058D9f03360B04eeF29C1");
  // console.log("Deploying contracts with the account:", deployer.address);
  // const token = await ethers.deployContract("BCoinToken");
  // console.log("Token address:", await token.getAddress());
  // ===

  // === BBridge ===
  // const [deployer] = await ethers.getSigners("0xD53b028d9b38A78564E058D9f03360B04eeF29C1");
  // console.log("Deploying contracts with the account:", deployer.address);
  
  // const ledger = await new LedgerSigner(hre.ethers.provider, "hid", "m/44'/60'/0'/0");  hre.network.provider
  // const ledger = new LedgerSigner();
  const BBridge = await hre.network.provider.getContractFactory("BBridge");
  let BBBridge = await BBridge.connect(ledger)

  
  // // *** deploy new proxy ***
  const bBridge = await upgrades.deployProxy(BBBridge, ["0x648a9CF8E95c73110D28E7e2329b2D0910Bd36B8"], { initializer: "initialize" });
  await bBridge.waitForDeployment();
  // ***
  
  // *** upgrade existing proxy ***
  //const proxyBridgeAddr = "0x7aaa1103C224f73cB41cA3b342e1CCBD3A8F49a6"; // BNB
  //const proxyBridgeAddr = "0xA261675dB71E1cb9fA295C6f13CcF5292986a303"; // Polygon

  //const bBridge = await upgrades.upgradeProxy(proxyBridgeAddr, BBridge);
  //await bBridge.waitForDeployment();
  // ***
  // ===
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

  // async function main() {
  //   const [deployer] = await ethers.getSigners();
  
  //   console.log("Deploying contracts with the account:", deployer.address);
  
  //   const token = await ethers.deployContract("BBridge");
  
  //   console.log("Contract address:", await token.getAddress());
  // }
  
  // main()
  //   .then(() => process.exit(0))
  //   .catch((error) => {
  //     console.error(error);
  //     process.exit(1);
  //   });