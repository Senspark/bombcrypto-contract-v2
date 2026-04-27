const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("=== NFT Shield Stress Tests ===", function () {

  async function deployStressFixture() {
    const [owner, addr1, addr2, signerAccount] = await ethers.getSigners();

    const bheroTokenContract_ = await ethers.getContractFactory("MockShieldToken");
    const bheroTokenContract = await upgrades.deployProxy(bheroTokenContract_, [], { initializer: "initialize" });
    await bheroTokenContract.waitForDeployment();

    // Set signer
    await bheroTokenContract.setShieldSigner(signerAccount.address);

    // Mint 50 heroes for stress testing
    const tokenIds = [];
    for (let i = 1; i <= 50; i++) {
      await bheroTokenContract.testMint(owner.address, i);
      tokenIds.push(i);
    }

    return { owner, addr1, addr2, signerAccount, bheroTokenContract, tokenIds };
  }

  // Helper to generate signature
  async function generateSignature(signerAccount, userAddress, nonce, dataArray) {
    const rawMessageHash = ethers.solidityPackedKeccak256(
      ["address", "uint256", "uint256[]"],
      [userAddress, nonce, dataArray]
    );

    const messageBytes = ethers.getBytes(rawMessageHash);
    const signature = await signerAccount.signMessage(messageBytes);
    return signature;
  }

  describe("Bulk Operations Gas Analysis", function () {
    it("Should measure gas for unlocking 10 tokens", async function () {
      const { bheroTokenContract, owner, signerAccount } = await loadFixture(deployStressFixture);
      await bheroTokenContract.activateShield();
      
      const tokensToUnlock = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      const nonce = await bheroTokenContract.shieldNonce(owner.address);
      const signature = await generateSignature(signerAccount, owner.address, nonce, tokensToUnlock);

      const tx = await bheroTokenContract.unlockTokensWithSignature(tokensToUnlock, nonce, signature);
      const receipt = await tx.wait();
      console.log(`      Gas used for unlocking 10 tokens: ${receipt.gasUsed.toString()}`);
      
      expect(await bheroTokenContract.isTokenUnlocked(1)).to.equal(true);
      expect(await bheroTokenContract.isTokenUnlocked(10)).to.equal(true);
    });

    it("Should measure gas for unlocking 50 tokens", async function () {
      const { bheroTokenContract, owner, signerAccount, tokenIds } = await loadFixture(deployStressFixture);
      await bheroTokenContract.activateShield();
      
      const nonce = await bheroTokenContract.shieldNonce(owner.address);
      const signature = await generateSignature(signerAccount, owner.address, nonce, tokenIds);

      const tx = await bheroTokenContract.unlockTokensWithSignature(tokenIds, nonce, signature);
      const receipt = await tx.wait();
      console.log(`      Gas used for unlocking 50 tokens: ${receipt.gasUsed.toString()}`);
      
      expect(await bheroTokenContract.isTokenUnlocked(1)).to.equal(true);
      expect(await bheroTokenContract.isTokenUnlocked(50)).to.equal(true);
    });

    it("Should measure gas for locking 50 tokens manually", async function () {
      const { bheroTokenContract, owner, tokenIds } = await loadFixture(deployStressFixture);
      // Ensure they are unlocked first
      for(let id of tokenIds) {
          // In mock, they might be unlocked by default or after activation
      }
      
      const tx = await bheroTokenContract.lockTokens(tokenIds);
      const receipt = await tx.wait();
      console.log(`      Gas used for manually locking 50 tokens: ${receipt.gasUsed.toString()}`);
      
      expect(await bheroTokenContract.isTokenUnlocked(1)).to.equal(false);
      expect(await bheroTokenContract.isTokenUnlocked(50)).to.equal(false);
    });
  });

  describe("Security Stress", function () {
    it("Should handle 10 consecutive unlock/transfer cycles", async function () {
      const { bheroTokenContract, owner, addr1, signerAccount } = await loadFixture(deployStressFixture);
      await bheroTokenContract.activateShield();

      for (let i = 1; i <= 10; i++) {
        const nonce = await bheroTokenContract.shieldNonce(owner.address);
        const signature = await generateSignature(signerAccount, owner.address, nonce, [i]);
        
        await bheroTokenContract.unlockTokensWithSignature([i], nonce, signature);
        await bheroTokenContract.transferFrom(owner.address, addr1.address, i);
        
        expect(await bheroTokenContract.ownerOf(i)).to.equal(addr1.address);
        expect(await bheroTokenContract.isTokenUnlocked(i)).to.equal(false); // Auto re-locked
      }
    });
  });
});
