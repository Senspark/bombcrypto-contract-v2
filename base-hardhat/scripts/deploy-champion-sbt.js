

async function main() {

  // === Master reward pool ==  
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  const Contract = await ethers.getContractFactory("ChampionSBT");
  
  // *** deploy new proxy ***
  // Master reward pool
  const deployedContract = await upgrades.deployProxy(Contract, [], { initializer: "initialize" });
  await deployedContract.waitForDeployment();
  // ***
  
  // *** upgrade existing proxy ***
  //const proxyAddr = "0x2607A35fb2D56d07c16f96704b99ECFECA2cF703"; // BNB
  // const proxyAddr = ""; // Polygon

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