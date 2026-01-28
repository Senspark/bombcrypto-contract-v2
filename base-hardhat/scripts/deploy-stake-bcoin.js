async function main() {
  // === Stake BCoin ===
  
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  
  const Contract = await ethers.getContractFactory("BCoinStakeNewName");

  // // *** deploy new proxy ***
  //mainnet
  const deployedContract = await upgrades.deployProxy(Contract, ["0xB2C63830D4478cB331142FAc075A39671a5541dC","0xB2C63830D4478cB331142FAc075A39671a5541dC"], { initializer: "initialize" });
  //testnet
  //const deployedContract = await upgrades.deployProxy(Contract, ["0xcF693b54F86c49bbBa54Ff887488Bbf84C5D05BF","0xcF693b54F86c49bbBa54Ff887488Bbf84C5D05BF"], { initializer: "initialize" });
  
  await deployedContract.waitForDeployment();

  // *** upgrade existing proxy ***
  // const proxyAddr = "0x1CF220128D22B9c272260c6B9Ff84Eed77Dba6F1"; // BNB
  // const proxyAddr = "0x1CF220128D22B9c272260c6B9Ff84Eed77Dba6F1"; // BNB Testnet
  // const proxyAddr = "0x1CF220128D22B9c272260c6B9Ff84Eed77Dba6F1"; // Polygon 
  // const proxyAddr = "0x1CF220128D22B9c272260c6B9Ff84Eed77Dba6F1"; // Poygon Testnet
  
  // --- force Impl ---
  // await upgrades.forceImport(proxyBCoinStakingAddr, BCoinStaking);
  // ---

  // --- upgrade proxy ---
  // const bcoinStaking = await upgrades.upgradeProxy(proxyBCoinStakingAddr, BCoinStaking);
  // await bcoinStaking.waitForDeployment();
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