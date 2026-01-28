

async function main() {

  // === BBridge ==  
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  const Contract = await ethers.getContractFactory("BBridge");
  
  // // *** deploy new proxy ***
  // bcoin bridge 
  // BNB mainnet
  // const deployedContract = await upgrades.deployProxy(Contract, ["0xcF693b54F86c49bbBa54Ff887488Bbf84C5D05BF"], { initializer: "initialize" });
  // BNB testnet
  // const deployedContract = await upgrades.deployProxy(Contract, ["0xcF693b54F86c49bbBa54Ff887488Bbf84C5D05BF"], { initializer: "initialize" });
  // Polygon mainnet
  // const deployedContract = await upgrades.deployProxy(Contract, ["0xcF693b54F86c49bbBa54Ff887488Bbf84C5D05BF"], { initializer: "initialize" });
  // Polygon testnet
  // const deployedContract = await upgrades.deployProxy(Contract, ["0xcF693b54F86c49bbBa54Ff887488Bbf84C5D05BF"], { initializer: "initialize" });

  //sen bridge
  // BNB mainnet
  // const deployedContract = await upgrades.deployProxy(Contract, ["0xcF693b54F86c49bbBa54Ff887488Bbf84C5D05BF"], { initializer: "initialize" });
  // BNB testnet
  // const deployedContract = await upgrades.deployProxy(Contract, ["0xcF693b54F86c49bbBa54Ff887488Bbf84C5D05BF"], { initializer: "initialize" });
  // Polygon mainnet
  // const deployedContract = await upgrades.deployProxy(Contract, ["0xFe302B8666539d5046cd9aA0707bB327F5f94C22"], { initializer: "initialize" });
  // Polygon testnet
  // const deployedContract = await upgrades.deployProxy(Contract, ["0x93567522610828695F36178b180989996082404A"], { initializer: "initialize" });
  
  // await deployedContract.waitForDeployment();
  // ***

  
  
  // *** upgrade existing proxy ***
  
  // Bcoin bridge 
  // BNB mainnet
  // const proxyAddr = "0x44ADc72f9b24692838FE32e9200034dD1a7c0C63";
  // BNB testnet
  // const proxyAddr = "0x7aaa1103C224f73cB41cA3b342e1CCBD3A8F49a6";
  // Polygon mainnet
  // const proxyAddr = "0x6864C7370AF52A68677041E1Eb88f38c729ff315";
  // Polygon testnet
  // const proxyAddr = "0x6d3ef73A656E1a38ff7fcF14B919Bee3d6006111";

  // Sen bridge 
  // BNB mainnet
  // const proxyAddr = "0xbD290fbB695090EBa8d3e33Ed18d41e9A36Fbe26"; 
  // BNB testnet
  // const proxyAddr = "0x9EDd800202e92b187d62AEd8Dd88D8457f360c1b";
  // Polygon mainnet
  // const proxyAddr = "0x450d5b5606A77BDFAbed96CD47d10833AB346686";
  // Polygon testnet
  const proxyAddr = "0x6A5E98D87128F8e76505eF8ca96A66DcE0905E18";

  // --- force Impl (old proxy contract) --- 
  // await upgrades.forceImport(proxyAddr, Contract);
  // ---

  // --- upgrade proxy ---
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