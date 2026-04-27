const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("=== NFT Shield System ===", function () {

  async function deployShieldFixture() {
    const [owner, addr1, addr2, signerAccount] = await ethers.getSigners();

    const bheroTokenContract_ = await ethers.getContractFactory("MockShieldToken");
    const bheroTokenContract = await upgrades.deployProxy(bheroTokenContract_, [], { initializer: "initialize" });
    await bheroTokenContract.waitForDeployment();

    // Set signer
    await bheroTokenContract.setShieldSigner(signerAccount.address);

    // Provide some heroes using the mock mint
    await bheroTokenContract.testMint(owner.address, 1);
    await bheroTokenContract.testMint(owner.address, 2);

    return { owner, addr1, addr2, signerAccount, bheroTokenContract };
  }

  // Helper to generate signature
  async function generateSignature(signerAccount, userAddress, nonce, dataArray, isDisable = false) {
    let rawMessageHash;
    if (isDisable) {
      rawMessageHash = ethers.solidityPackedKeccak256(
        ["address", "uint256", "string"],
        [userAddress, nonce, "DISABLE_SHIELD"]
      );
    } else {
      rawMessageHash = ethers.solidityPackedKeccak256(
        ["address", "uint256", "uint256[]"],
        [userAddress, nonce, dataArray]
      );
    }

    const messageBytes = ethers.getBytes(rawMessageHash);
    const signature = await signerAccount.signMessage(messageBytes);
    return signature;
  }

  describe("Setup & Manual Locking", function () {
    it("Should allow user to activate shield", async function () {
      const { bheroTokenContract, owner } = await loadFixture(deployShieldFixture);
      
      await bheroTokenContract.activateShield();

      expect(await bheroTokenContract.isShieldActive(owner.address)).to.equal(true);
    });

    it("Should allow user to lock specific tokens", async function () {
      const { bheroTokenContract, owner } = await loadFixture(deployShieldFixture);
      
      await bheroTokenContract.lockTokens([1, 2]);

      expect(await bheroTokenContract.isTokenUnlocked(1)).to.equal(false);
      expect(await bheroTokenContract.isTokenUnlocked(2)).to.equal(false);
    });

    it("Should revert if trying to lock token not owned", async function () {
      const { bheroTokenContract, addr1 } = await loadFixture(deployShieldFixture);
      await expect(bheroTokenContract.connect(addr1).lockTokens([1]))
        .to.be.revertedWith("Not owner");
    });
  });

  describe("Transfer Guard", function () {
    it("Should allow transfer if shield is NOT active", async function () {
      const { bheroTokenContract, owner, addr1 } = await loadFixture(deployShieldFixture);
      await bheroTokenContract.transferFrom(owner.address, addr1.address, 1);
      expect(await bheroTokenContract.ownerOf(1)).to.equal(addr1.address);
    });

    it("Should revert transfer if shield is active and token is locked", async function () {
      const { bheroTokenContract, owner, addr1 } = await loadFixture(deployShieldFixture);
      
      await bheroTokenContract.activateShield();
      // By default tokens are locked when shield is active (isTokenUnlocked == false)
      
      await expect(bheroTokenContract.transferFrom(owner.address, addr1.address, 1))
        .to.be.revertedWith("NFT Shield: Token is locked. Unlock it in-game.");
    });
  });

  describe("Server-Side Signature Unlocking", function () {
    it("Should allow unlock with valid backend signature", async function () {
      const { bheroTokenContract, owner, signerAccount } = await loadFixture(deployShieldFixture);
      
      await bheroTokenContract.activateShield();
      
      const nonce = await bheroTokenContract.shieldNonce(owner.address);
      const signature = await generateSignature(signerAccount, owner.address, nonce, [1]);

      await expect(bheroTokenContract.unlockTokensWithSignature([1], nonce, signature))
        .to.emit(bheroTokenContract, "TokenUnlocked")
        .withArgs(1);

      expect(await bheroTokenContract.isTokenUnlocked(1)).to.equal(true);
    });

    it("Should allow transfer after token is unlocked", async function () {
      const { bheroTokenContract, owner, addr1, signerAccount } = await loadFixture(deployShieldFixture);
      
      await bheroTokenContract.activateShield();
      
      const nonce = await bheroTokenContract.shieldNonce(owner.address);
      const signature = await generateSignature(signerAccount, owner.address, nonce, [1]);
      await bheroTokenContract.unlockTokensWithSignature([1], nonce, signature);

      // Now transfer should succeed
      await bheroTokenContract.transferFrom(owner.address, addr1.address, 1);
      expect(await bheroTokenContract.ownerOf(1)).to.equal(addr1.address);
      
      // Auto re-lock mechanism: the token should be locked again after transfer
      expect(await bheroTokenContract.isTokenUnlocked(1)).to.equal(false);
    });

    it("Should revert unlock with invalid signature", async function () {
      const { bheroTokenContract, owner, addr2 } = await loadFixture(deployShieldFixture);
      
      await bheroTokenContract.activateShield();
      
      const nonce = await bheroTokenContract.shieldNonce(owner.address);
      // Generate with WRONG signer
      const invalidSignature = await generateSignature(addr2, owner.address, nonce, [1]);

      await expect(
        bheroTokenContract.unlockTokensWithSignature([1], nonce, invalidSignature)
      ).to.be.revertedWith("Bad sig");
    });
    
    it("Should revert unlock with invalid nonce", async function () {
      const { bheroTokenContract, owner, signerAccount } = await loadFixture(deployShieldFixture);
      
      await bheroTokenContract.activateShield();
      
      const nonce = await bheroTokenContract.shieldNonce(owner.address);
      const signature = await generateSignature(signerAccount, owner.address, nonce, [1]);

      await expect(
        bheroTokenContract.unlockTokensWithSignature([1], nonce + 1n, signature)
      ).to.be.revertedWith("Bad shield state");
    });
  });

  describe("Emergency Disable", function () {
    it("Should start emergency cooldown", async function () {
      const { bheroTokenContract, owner } = await loadFixture(deployShieldFixture);
      await bheroTokenContract.activateShield();

      await bheroTokenContract.requestEmergencyDisable();

      const startTime = await bheroTokenContract.emergencyUnlockStart(owner.address);
      expect(startTime).to.be.greaterThan(0);
    });

    it("Should revert execution if cooldown not finished", async function () {
      const { bheroTokenContract, owner } = await loadFixture(deployShieldFixture);
      await bheroTokenContract.activateShield();
      await bheroTokenContract.requestEmergencyDisable();

      await time.increase(3 * 24 * 60 * 60); // 3 days

      await expect(bheroTokenContract.executeEmergencyDisable()).to.be.revertedWith(
        "Cooldown"
      );
    });

    it("Should execute successfully after 7 days", async function () {
      const { bheroTokenContract, owner } = await loadFixture(deployShieldFixture);
      await bheroTokenContract.activateShield();
      await bheroTokenContract.requestEmergencyDisable();

      await time.increase(7 * 24 * 60 * 60 + 1); // 7 days + 1 sec

      await expect(bheroTokenContract.executeEmergencyDisable())
        .to.emit(bheroTokenContract, "ShieldDeactivated")
        .withArgs(owner.address);

      expect(await bheroTokenContract.isShieldActive(owner.address)).to.equal(false);
      expect(await bheroTokenContract.emergencyUnlockStart(owner.address)).to.equal(0);
    });

    it("Should allow cancellation during cooldown", async function () {
      const { bheroTokenContract, owner } = await loadFixture(deployShieldFixture);
      await bheroTokenContract.activateShield();
      await bheroTokenContract.requestEmergencyDisable();

      await bheroTokenContract.cancelEmergencyDisable();

      expect(await bheroTokenContract.emergencyUnlockStart(owner.address)).to.equal(0);
    });
  });

});
