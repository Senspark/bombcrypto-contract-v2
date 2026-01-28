

async function main() {

  // === Presale ==  
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  const Contract = await ethers.getContractFactory("SenPolygonPresale");
  
  // // *** deploy new proxy ***
  // BNB
  // const deployedContract = await upgrades.deployProxy(Contract,
  //   ["0x00e1656e45f18ec6747F5a8496Fd39B50b38396D", //BCOIN / BOMB
  //   "0xb43Ac9a81eDA5a5b36839d5b6FC65606815361b0",  // SEN
  //   "0x55d398326f99059fF775485246999027B3197955"], // USDT
  //    { initializer: "initialize" });

  // Polygon
  // const deployedContract = await upgrades.deployProxy(Contract, 
  //   ["0xB2C63830D4478cB331142FAc075A39671a5541dC", //BCOIN / BOMB
  //   "0xFe302B8666539d5046cd9aA0707bB327F5f94C22",  // SEN
  //   "0xc2132D05D31c914a87C6611C10748AEb04B58e8F"], // USDT
  //     { initializer: "initialize" });

  // await deployedContract.waitForDeployment();
  // ***
  
  // *** upgrade existing proxy ***
  // const proxyAddr = "0x5dfF1d09174eC202728Ba96a9260B13E74Df434A"; // BNB Mainnet
  // const proxyAddr = "0xCD58c3237fb5bFBa2b38F4BcA39ac0C5feAf44A4"; // BNB Testnet
  const proxyAddr = "0xB4665217E025571fEF84C65a391210B62a7c7101"; // Polygon Mainnet
  // const proxyAddr = "0xAf800581a1Cf7315ae4CA77b64522D51c62D912f"; // Polygon Testnet

  const deployedContract = await upgrades.upgradeProxy(proxyAddr, Contract);
  await deployedContract.waitForDeployment();
  // ***
  // ===
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });