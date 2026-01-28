const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  const network = hre.network.name;
  console.log(`\n💰 Withdrawing funds from NativeTokenDepositor on ${network}...`);

  // Check if deployment exists
  const deploymentPath = path.join(__dirname, `../deployments/${network}/NativeTokenDepositor.json`);
  if (!fs.existsSync(deploymentPath)) {
    console.error(`❌ No deployment found for ${network}`);
    console.error(`Please deploy the contract first using: npx hardhat deploy --network ${network}`);
    process.exit(1);
  }

  // Read deployment data
  const deploymentData = JSON.parse(fs.readFileSync(deploymentPath, 'utf8'));
  const proxyAddress = deploymentData.address;

  console.log(`📍 Contract Address: ${proxyAddress}`);

  // Get the contract factory and connect to the proxy
  const NativeTokenDepositor = await ethers.getContractFactory("NativeTokenDepositor");
  const contract = NativeTokenDepositor.attach(proxyAddress);

  // Get signer info
  const [signer] = await ethers.getSigners();
  console.log(`👤 Withdrawing with account: ${signer.address}`);

  try {
    // Check ownership
    const owner = await contract.owner();
    console.log(`👤 Contract Owner: ${owner}`);
    
    if (owner.toLowerCase() !== signer.address.toLowerCase()) {
      console.error(`❌ Access denied: You are not the contract owner`);
      console.error(`   Required: ${owner}`);
      console.error(`   Your address: ${signer.address}`);
      process.exit(1);
    }

    // Check contract balance
    const balance = await ethers.provider.getBalance(proxyAddress);
    const balanceInEther = ethers.formatEther(balance);
    
    console.log(`💰 Contract Balance: ${balanceInEther} ETH`);
    
    if (balance === 0n) {
      console.log(`ℹ️  No funds to withdraw. Contract balance is 0.`);
      process.exit(0);
    }

    // Get owner's current balance
    const ownerBalance = await ethers.provider.getBalance(signer.address);
    const ownerBalanceInEther = ethers.formatEther(ownerBalance);
    console.log(`👤 Owner Balance: ${ownerBalanceInEther} ETH`);

    // Confirmation prompt
    console.log(`\n⚠️  DANGER: This will withdraw ALL funds from the contract!`);
    console.log(`💰 Amount to withdraw: ${balanceInEther} ETH`);
    console.log(`📍 Funds will be sent to: ${signer.address}`);
    console.log(`\n⚠️  This action cannot be undone!`);
    console.log(`⏳ Starting withdrawal in 5 seconds... (Press Ctrl+C to cancel)`);
    
    await new Promise(resolve => setTimeout(resolve, 5000));

    console.log(`\n🔄 Executing withdrawal...`);
    
    // Execute withdrawal
    const tx = await contract.withdraw();
    console.log(`📝 Transaction submitted: ${tx.hash}`);
    
    // Wait for confirmation
    const receipt = await tx.wait();
    console.log(`✅ Transaction confirmed in block: ${receipt.blockNumber}`);
    
    // Verify withdrawal
    const newContractBalance = await ethers.provider.getBalance(proxyAddress);
    const newOwnerBalance = await ethers.provider.getBalance(signer.address);
    
    console.log(`\n💰 Withdrawal Summary:`);
    console.log(`   Contract Balance: ${ethers.formatEther(newContractBalance)} ETH (was ${balanceInEther} ETH)`);
    console.log(`   Owner Balance: ${ethers.formatEther(newOwnerBalance)} ETH (was ${ownerBalanceInEther} ETH)`);
    console.log(`   Gas Used: ${receipt.gasUsed.toString()}`);
    
    if (newContractBalance === 0n) {
      console.log(`✅ Withdrawal successful! All funds have been transferred.`);
    } else {
      console.log(`⚠️  Warning: Contract still has ${ethers.formatEther(newContractBalance)} ETH remaining.`);
    }
    
  } catch (error) {
    console.error(`❌ Withdrawal failed: ${error.message}`);
    
    // Additional error handling for common issues
    if (error.message.includes("No funds to withdraw")) {
      console.error(`ℹ️  The contract has no funds to withdraw.`);
    } else if (error.message.includes("OwnableUnauthorizedAccount")) {
      console.error(`ℹ️  Only the contract owner can withdraw funds.`);
    } else if (error.message.includes("Withdrawal failed")) {
      console.error(`ℹ️  The withdrawal transaction failed. This could be due to insufficient gas or a contract issue.`);
    }
    
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });