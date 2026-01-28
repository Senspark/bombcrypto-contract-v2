

async function main() {

  // === Master reward pool ==  
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  const Contract = await ethers.getContractFactory("MasterRewardPool");
  
  // *** deploy new proxy ***
  // Master reward pool
  const deployedContract = await upgrades.deployProxy(Contract, [], { initializer: "initialize" });
  await deployedContract.waitForDeployment();
  // ***
  
  // *** upgrade existing proxy ***
  //const proxyAddr = "0x44ADc72f9b24692838FE32e9200034dD1a7c0C63"; // BNB
  // const proxyAddr = "0x6864C7370AF52A68677041E1Eb88f38c729ff315"; // Polygon

  // const deployedContract = await upgrades.upgradeProxy(proxyAddr, Contract);
  // await deployedContract.waitForDeployment();
  // ***
  // ===
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });