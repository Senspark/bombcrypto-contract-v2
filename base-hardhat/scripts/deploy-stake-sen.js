async function main() {
  // === Stake Sen ===
  
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  
  const Contract = await ethers.getContractFactory("SenStake");

   // // *** deploy new proxy ***
  // testnet
  const deployedContract = await upgrades.deployProxy(Contract, ["0x93567522610828695F36178b180989996082404A","0x93567522610828695F36178b180989996082404A"], { initializer: "initialize" });
  await deployedContract.waitForDeployment();
  
  // *** upgrade existing proxy ***
  // const proxyAddr = "0x4FD4a6905eF6b0084af1e4912bB81ED41A1bDa21"; // BNB
  // const proxyAddr = "0x4FD4a6905eF6b0084af1e4912bB81ED41A1bDa21"; // BNB testnet
  // const proxyAddr = "0x4FD4a6905eF6b0084af1e4912bB81ED41A1bDa21"; // Polygon
  // const proxyAddr = "0x4FD4a6905eF6b0084af1e4912bB81ED41A1bDa21"; // Polygon testnet

  
  // --- force Impl ---
  //await upgrades.forceImport(proxyAddr, SenStake);
  // ---

  // --- upgrade proxy ---
  // const deployedContract = await upgrades.upgradeProxy(proxyAddr, contract);
  // await deployedContract.waitForDeployment();
  // ---
  // ***

  // ===
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });