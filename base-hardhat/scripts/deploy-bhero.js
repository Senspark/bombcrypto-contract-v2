

async function main() {

  // === BHero ===
  
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  
  // const Contract = await ethers.getContractFactory("BHeroToken");
  // const Contract = await ethers.getContractFactory("BHeroDesign");
  // const Contract = await ethers.getContractFactory("BHeroS");
  const Contract = await ethers.getContractFactory("BHeroStake");
  // const Contract = await ethers.getContractFactory("BHeroMarket");
  

  // // *** deploy new proxy ***
  // bhero token testnet
  // const deployedContract = await upgrades.deployProxy(Contract, ["0xcF693b54F86c49bbBa54Ff887488Bbf84C5D05BF"], { initializer: "initialize" }); 
  // bhero design testnet
  // const deployedContract = await upgrades.deployProxy(Contract, [], { initializer: "initialize" }); 
  // bhero s testnet
  // const deployedContract = await upgrades.deployProxy(Contract, ["0xF9f21032bcCCe8997bB29Ab9FBE19502191B7596"], { initializer: "initialize" }); 
  // ** bhero market **
  // polygon testnet aloy
  // const deployedContract = await upgrades.deployProxy(Contract, ["0xcF693b54F86c49bbBa54Ff887488Bbf84C5D05BF", "0xF9f21032bcCCe8997bB29Ab9FBE19502191B7596"], { initializer: "initialize" }); 
  // polygon mainnet
  // const deployedContract = await upgrades.deployProxy(Contract, ["0xB2C63830D4478cB331142FAc075A39671a5541dC", "0xd8a06936506379dbbe6e2d8ab1d8c96426320854"], { initializer: "initialize" }); 
  
  // ** bhero stake **
  // BNB mainnet
  // const deployedContract = await upgrades.deployProxy(Contract, ["0x00e1656e45f18ec6747F5a8496Fd39B50b38396D", "0x30cc0553f6fa1faf6d7847891b9b36eb559dc618"], { initializer: "initialize" });
  // BNB testnet
  // const deployedContract = await upgrades.deployProxy(Contract, ["0xcF693b54F86c49bbBa54Ff887488Bbf84C5D05BF", "0xF9f21032bcCCe8997bB29Ab9FBE19502191B7596"], { initializer: "initialize" });
  // Polygon mainnet
  // const deployedContract = await upgrades.deployProxy(Contract, ["0xB2C63830D4478cB331142FAc075A39671a5541dC", "0xd8a06936506379dbbe6e2d8ab1d8c96426320854"], { initializer: "initialize" });
  // Polygon testnet
  // const deployedContract = await upgrades.deployProxy(Contract, ["0xcF693b54F86c49bbBa54Ff887488Bbf84C5D05BF", "0xF9f21032bcCCe8997bB29Ab9FBE19502191B7596"], { initializer: "initialize" });
  
  // await deployedContract.waitForDeployment();
  // ***
  
  // *** upgrade existing proxy ***
  // Bhero Token
  // const proxyAddr = "0x30cc0553f6fa1faf6d7847891b9b36eb559dc618"; // BNB
  // const proxyAddr = "0xC1A4C06426B4Df799E455964A20FDe866E86fbd1"; // BNB Testnet
  // const proxyAddr = "0xd8a06936506379dbbe6e2d8ab1d8c96426320854"; // Polygon
  // const proxyAddr = "0xF9f21032bcCCe8997bB29Ab9FBE19502191B7596"; // Polygon Amoy

  // Bhero Design
  // const proxyAddr = "0x516e792268416c58b82565CeF088cFB9575A750a"; // BNB
  // const proxyAddr = "0x124c7569D4E1723b5e90a81E8dc9b5237444D190"; // Polygon
  //const proxyAddr = "0x9d294B9ADE72CFbE323AA34B99893cDE8a6cE673"; // Polygon Amoy

  // Bhero S
  // const proxyAddr = "0x9fb9b7349279266c85c0C9dd264D71d2a4B79AB4"; // BNB
  // const proxyAddr = "0x2c5a4C5978b814105EDb7148F37Fe07157E03bAD"; // BNB Testnet
  // const proxyAddr = "0x27313635E6B7AA3CC8436E24BE2317D4A0e56BeB"; // Polygon
  // const proxyAddr = "0x5F2a8Aa67E11626AD9Dc5671f8cD29762D4532d4"; // Polygon Amoy

  // Bhero Stake
  // const proxyAddr = "0x053282c295419E67655a5032A4DA4e3f92D11F17"; // BNB
  // const proxyAddr = "0xe3D882b5FC1654782D6579c876975324Ab4D3d07"; // BNB testnet
  const proxyAddr = "0x810570AA7e16cF14DefD69D4C9796f3c1Abe2d13"; // Polygon
  //const proxyAddr = "0x9b5d2671665d302d5011959236f5b395e753dccd"; // Polygon Amoy

  // Bhero Market
  // const proxyAddr = "0x376A10E7f125A4E0a567cc08043c695Cd8EDd704"; // BNB
  // const proxyAddr = "0x0A32cD1069cf6b4A11b79b37aFb2A13598E6E5ca"; // BNB testnet
  // const proxyAddr = "0xf3a7195920519f8A22cDf84EBB9F74342abE9812"; // Polygon
  // const proxyAddr = "0xf3a7195920519f8A22cDf84EBB9F74342abE9812"; // Polygon Amoy
  
  
  // --- force Impl (old proxy contract) --- 
  // await upgrades.forceImport(proxyAddr, Contract);
  // ---

  // --- upgrade proxy ---
  const deployedContract = await upgrades.upgradeProxy(proxyAddr, Contract);
  await deployedContract.waitForDeployment();
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