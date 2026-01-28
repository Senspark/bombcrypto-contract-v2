

async function main() {

  // === BHouse ===
  
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  
  // const Contract = await ethers.getContractFactory("BHouseToken");
  // const Contract = await ethers.getContractFactory("BHouseDesign");
  const Contract = await ethers.getContractFactory("BHouseMarket");

  // // *** deploy new proxy 
  // ** bhouse token **
  // polygon testnet
  //const deployedContract = await upgrades.deployProxy(Contract, ["0xcF693b54F86c49bbBa54Ff887488Bbf84C5D05BF"], { initializer: "initialize" }); 

  // ** bhouse design **
  // testnet
  // const deployedContract = await upgrades.deployProxy(Contract, [], { initializer: "initialize" }); 

  // ** bhouse market **
  // polygon mainnet 
  // const deployedContract = await upgrades.deployProxy(Contract, ["0xB2C63830D4478cB331142FAc075A39671a5541dC", "0x2d5f4ba3e4a2d991bd72edbf78f607c174636618", ], { initializer: "initialize" }); 
  // polygon testnet 
  // const deployedContract = await upgrades.deployProxy(Contract, ["0xcF693b54F86c49bbBa54Ff887488Bbf84C5D05BF", "0x0fc7397017f1bebaf8ffe8220871af2b5b65509d", ], { initializer: "initialize" }); 
  
  
  // ***

  
  
  // *** upgrade existing proxy ***
  // ** BHouse Token
  // const proxyAddr = "0xea3516fEB8F3e387eeC3004330Fd30Aff615496A"; // BNB
  // const proxyAddr = "0xea3516fEB8F3e387eeC3004330Fd30Aff615496A"; // BNB Testnet
  // const proxyAddr = "0x2d5f4ba3e4a2d991bd72edbf78f607c174636618"; // Polygon
  // const proxyAddr = "0x0fc7397017f1bebaf8ffe8220871af2b5b65509d"; // Polygon Testnet Amoy

  // ** BHouse Market
  const proxyAddr = "0x049896f350C802CD5C91134E5f35Ec55FA8f0108"; // BNB
  // const proxyAddr = "0x19E4320D81954fB1321d2e4cc5C1eA064a289aaf"; // BNB Testnet
  // const proxyAddr = "0xBb5966daF83ec4D3f168671a464EB18430EeA3be"; // Polygon
  // const proxyAddr = "0x23094e46b74BF9352720a14CcbEf5C85496f65FC"; // Polygon Testnet Amoy

  // ** BHouse Design

  // ** BHouse Market


  
  
  // --- force Impl ---
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