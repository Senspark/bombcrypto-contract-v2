

async function main() {

  // === Deposit ===
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  const Contract = await ethers.getContractFactory("Deposit");
  
  // // *** deploy new proxy ***
  // BNB Testnet
  // const deployedContract = await upgrades.deployProxy(Contract, ["0x648a9cf8e95c73110d28e7e2329b2d0910bd36b8"], { initializer: "initialize" });
  // Polygon Amoy
  // const deployedContract = await upgrades.deployProxy(Contract, ["0xcF693b54F86c49bbBa54Ff887488Bbf84C5D05BF"], { initializer: "initialize" });
  // await deployedContract.waitForDeployment();
  // ***
  
  
  // *** upgrade existing proxy ***
  // const proxyAddr = "0xad5669fD304aF930C04B5bc7541e5285b638169d"; // BNB
  // const proxyAddr = "0x53Daf749ff71af11dd63c7c17296aFb6a45385Cb"; // BNB Testnet
  // const proxyAddr = "0x14EDbb72bd3318F84345bbe816bDef37814AC568"; // Polygon
  const proxyAddr = "0x48ce46d900105cf14ebf815c9980661c112b16b6"; // Polygon Testnet

  // --- force Impl (old proxy contract) --- 
  // await upgrades.forceImport(proxyAddr, Contract);
  // ---

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