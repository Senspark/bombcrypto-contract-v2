// This is an example test file. Hardhat will run every *.js file in `test/`,
// so feel free to add new ones.

// Hardhat tests are normally written with Mocha and Chai.

// We import Chai to use its asserting functions here.
const { expect } = require("chai");

const { ethers, upgrades} = require("hardhat");

// We use `loadFixture` to share common setups (or fixtures) between tests.
// Using this simplifies your tests and makes them run faster, by taking
// advantage of Hardhat Network's snapshot functionality.
const {
  loadFixture, time
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { EtherSymbol } = require("ethers");

// `describe` is a Mocha function that allows you to organize your tests.
// Having your tests organized makes debugging them easier. All Mocha
// functions are available in the global scope.
//
// `describe` receives the name of a section of your test suite, and a
// callback. The callback must define the tests of that section. This callback
// can't be an async function.


describe("=== BHeroStake ===", function () {

  // We define a fixture to reuse the same setup in every test. We use
  // loadFixture to run this setup once, snapshot that state, and reset Hardhat
  // Network to that snapshot in every test.

  async function deployTokenFixture() {
    // Get the Signers here.
    const [owner, addr1, addr2] = await ethers.getSigners();

    // To deploy our contract, we just have to call ethers.deployContract and await
    // its waitForDeployment() method, which happens once its transaction has been
    // mined.
    const bcoinToken = await ethers.deployContract("BCoinToken");
    await bcoinToken.waitForDeployment();
    //console.log("Bcoin address: ", await bcoinToken.getAddress());

    const senToken = await ethers.deployContract("SensparkPolygon");
    await senToken.waitForDeployment();
    //console.log("Sen address: ", await senToken.getAddress());

    const myNFTContract_ = await ethers.getContractFactory("MyNFT");
    const myNFTContract = await upgrades.deployProxy(myNFTContract_, [], { initializer: "initialize" });
    await myNFTContract.waitForDeployment();
    console.log("MYNFT Token address: ", await myNFTContract.getAddress());

    // Fixtures can return anything you consider useful for your tests
    return {owner, addr1, addr2, bcoinToken, senToken, myNFTContract};
  }

  async function deployBHeroTokenContractsFixture() {
    const {owner, addr1, addr2, bcoinToken, senToken} = await loadFixture(deployTokenFixture);
    const bheroTokenContract_ = await ethers.getContractFactory("BHeroToken");
    const bheroTokenContract = await upgrades.deployProxy(bheroTokenContract_, [await bcoinToken.getAddress()], { initializer: "initialize" });
    await bheroTokenContract.waitForDeployment();
    //console.log("BHero Token address: ", await bHeroTokenDeployedContract.getAddress());

    const bheroDesignContract_ = await ethers.getContractFactory("BHeroDesign");
    const bheroDesignContract = await upgrades.deployProxy(bheroDesignContract_, [], { initializer: "initialize" }); 
    await bheroDesignContract.waitForDeployment();

    const bheroSContract_ = await ethers.getContractFactory("BHeroS");
    const bheroSContract = await upgrades.deployProxy(bheroSContract_, [await bheroTokenContract.getAddress()], { initializer: "initialize" }); 
    await bheroSContract.waitForDeployment();

    // Thiết lập BHeroToken, BHeroDesign, BHeroS với nhau
    await bheroTokenContract.setDesign(bheroDesignContract);
    await bheroTokenContract.setSenToken(senToken);
    
    await bheroSContract.setBcoinToken(bcoinToken);
    await bheroSContract.setSenToken(senToken);

    await senToken.approve(bheroSContract, 10000000000000000000000n); //10k
    await bcoinToken.approve(bheroSContract, 10000000000000000000000n); //10k

    await bheroTokenContract.grantRole("0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6", bheroSContract); // minter role
    await bheroTokenContract.grantRole("0x3c11d16cbaffd01df69ce1c404f6340ee057498f5f00246190ea54220576a848", bheroSContract); // burner role

    return {owner, addr1, addr2, 
      bcoinToken, senToken, 
      bheroTokenContract, bheroSContract, bheroDesignContract};
  }

  async function deployBHeroStakeFixture() {
    // Get the Signers here.
    const {owner, addr1, addr2, bcoinToken, senToken, myNFTContract} = await loadFixture(deployTokenFixture);
    
    const bheroStakeContract_ = await ethers.getContractFactory("BHeroStake");
    const bheroStakeContract = await upgrades.deployProxy(bheroStakeContract_, [await bcoinToken.getAddress(), await myNFTContract.getAddress()], { initializer: "initialize" });
    await bheroStakeContract.waitForDeployment();
    console.log("BHero Stake address: ", await bheroStakeContract.getAddress());

    await senToken.approve(bheroStakeContract, 10000000000000000000000n); //10k
    await bcoinToken.approve(bheroStakeContract, 10000000000000000000000n); //10k
    
    // Fixtures can return anything you consider useful for your tests
    return {owner, addr1, addr2, 
      bcoinToken, senToken, 
      bheroStakeContract, myNFTContract};
  }

  describe("BHeroToken Deployment", function () {

    it("Check Bcoin token", async function () {
      const {owner, addr1, addr2, 
        bcoinToken, senToken, 
        bheroTokenContract, bheroSContract, bheroDesignContract, bheroStakeContract} = await loadFixture(deployBHeroTokenContractsFixture);
      
      expect(await bheroTokenContract.coinToken()).to.be.properAddress;
      expect(await bheroTokenContract.coinToken()).to.equal(bcoinToken);
    });

    it("Check Sen token", async function () {
      const {owner, addr1, addr2, 
        bcoinToken, senToken, 
        bheroTokenContract, bheroSContract, bheroDesignContract, bheroStakeContract} = await loadFixture(deployBHeroTokenContractsFixture);
      
      expect(await bheroTokenContract.senToken()).to.be.properAddress;
      expect(await bheroTokenContract.senToken()).to.equal(senToken);
    });

    it("Check BHeroDesign", async function () {
      const {owner, addr1, addr2, 
        bcoinToken, senToken, 
        bheroTokenContract, bheroSContract, bheroDesignContract, bheroStakeContract} = await loadFixture(deployBHeroTokenContractsFixture);
      
      expect(await bheroTokenContract.design()).to.be.properAddress;
      expect(await bheroTokenContract.design()).to.equal(bheroDesignContract);
    });
  });

  describe("BHeroDesign Deployment", function () {

    it("Check Mint Cost", async function () {
      const {owner, addr1, addr2, 
        bcoinToken, senToken, 
        bheroTokenContract, bheroSContract, bheroDesignContract, bheroStakeContract} = await loadFixture(deployBHeroTokenContractsFixture);
    
      expect(await bheroDesignContract.getMintCostHeroS()).to.equal(45000000000000000000n);
      expect(await bheroDesignContract.getSenMintCostHeroS()).to.equal(10000000000000000000n);
    });
  });

  describe("BHeroS Deployment", function () {

    it("Check Bcoin token", async function () {
      const {owner, addr1, addr2, 
        bcoinToken, senToken, 
        bheroTokenContract, bheroSContract, bheroDesignContract, bheroStakeContract} = await loadFixture(deployBHeroTokenContractsFixture);
      
      expect(await bheroSContract.bcoinToken()).to.be.properAddress;
      expect(await bheroSContract.bcoinToken()).to.equal(bcoinToken);
    });

    it("Check Sen token", async function () {
      const {owner, addr1, addr2, 
        bcoinToken, senToken, 
        bheroTokenContract, bheroSContract, bheroDesignContract, bheroStakeContract} = await loadFixture(deployBHeroTokenContractsFixture);
      
      expect(await bheroSContract.senToken()).to.be.properAddress;
      expect(await bheroSContract.senToken()).to.equal(senToken);
    });

    it("Check BHeroToken", async function () {
      const {owner, addr1, addr2, 
        bcoinToken, senToken, 
        bheroTokenContract, bheroSContract, bheroDesignContract, bheroStakeContract} = await loadFixture(deployBHeroTokenContractsFixture);
      
      expect(await bheroSContract.bHeroToken()).to.be.properAddress;
      expect(await bheroSContract.bHeroToken()).to.equal(bheroTokenContract);
    });

    /*it("Check Mint", async function () {
      const {owner, addr1, addr2, 
        bcoinToken, senToken, 
        bheroTokenContract, bheroSContract, bheroDesignContract, bheroStakeContract} = await loadFixture(deployBHeroStakeFixture);
      
      //

      console.log("Log bcoinToken.balanceOf(owner): ", await bcoinToken.balanceOf(owner));
      console.log("Log senToken.balanceOf(owner): ", await senToken.balanceOf(owner));
      const mintAmount = 5;
      await bheroSContract.mint(mintAmount);
      expect(await bheroTokenContract.balanceOf(owner)).to.equal(mintAmount);
    });*/
  });

  describe("MyNFT Deployment", function () {

    it("MyNFT Mint", async function () {
      const {owner, addr1, addr2, 
        bcoinToken, senToken, myNFTContract} = await loadFixture(deployTokenFixture);
      
      //
      console.log("Log bcoinToken.balanceOf(owner): ", await bcoinToken.balanceOf(owner));
      console.log("Log senToken.balanceOf(owner): ", await senToken.balanceOf(owner));
      await myNFTContract.mintNFT(owner);
      await myNFTContract.mintNFT(owner);
      expect(await myNFTContract.balanceOf(owner)).to.equal(2);
    });
  });

  // You can nest describe calls to create subsections.
  describe("BHeroStake Deployment", function () {

    it("Check Admin Role", async function () {
      const {owner, addr1, addr2, bcoinToken, senToken, bheroTokenContract, bheroStakeContract} = await loadFixture(deployBHeroStakeFixture);

      expect(await bheroStakeContract.hasRole("0x0000000000000000000000000000000000000000000000000000000000000000", owner.address)).to.equal(true); // admin
      expect(await bheroStakeContract.hasRole("0x22c69ab406805e70d07fb1a6502af760601d3b977beadb295a9d76d5852e16a3", owner.address)).to.equal(true); // designer
      expect(await bheroStakeContract.hasRole("0x189ab7a9244df0848122154315af71fe140f3db0fe014031783b0946b8c9d2e3", owner.address)).to.equal(true); // upgrader
      expect(await bheroStakeContract.hasRole("0x10dac8c06a04bec0b551627dad28bc00d6516b0caacd1c7b345fcdb5211334e4", owner.address)).to.equal(true); // withdrawer

    });

    it("Check nftToken", async function () {
      const {owner, addr1, addr2, bcoinToken, senToken, myNFTContract, bheroStakeContract} = await loadFixture(deployBHeroStakeFixture);
      
      //console.log("Log:", await bheroStakeContract.coinToken());

      expect(await bheroStakeContract.nftToken()).to.be.properAddress;
      expect(await bheroStakeContract.nftToken()).to.equal(myNFTContract);
    });

    it("Check coinToken", async function () {
      const {owner, addr1, addr2, bcoinToken, senToken, bheroStakeContract} = await loadFixture(deployBHeroStakeFixture);
      
      //console.log("Log:", await bheroStakeContract.coinToken());

      expect(await bheroStakeContract.coinToken()).to.be.properAddress;
      expect(await bheroStakeContract.coinToken()).to.equal(bcoinToken);
    });

  });

  describe("Stake V1", function () {
    it("Stake Coin", async function() {
      const {owner, addr1, addr2, bcoinToken, senToken, myNFTContract, bheroStakeContract} = await loadFixture(deployBHeroStakeFixture);
      await myNFTContract.mintNFT(owner);
      await bheroStakeContract.depositCoinIntoHeroId(1, 1000n);
      expect(await bheroStakeContract.getCoinBalancesByHeroId(1)).to.equal(1000n);
    });

    it("Withdraw Coin", async function() {
      const {owner, addr1, addr2, bcoinToken, senToken, myNFTContract, bheroStakeContract} = await loadFixture(deployBHeroStakeFixture);
      await myNFTContract.mintNFT(owner);
      await bheroStakeContract.depositCoinIntoHeroId(1, 1000n);
      await bheroStakeContract.withdrawCoinFromHeroId(1, 500n);
      expect(await bheroStakeContract.getCoinBalancesByHeroId(1)).to.equal(500n);
    });

    it("Withdraw Coin Exceeds Amount", async function() {
      const {owner, addr1, addr2, bcoinToken, senToken, myNFTContract, bheroStakeContract} = await loadFixture(deployBHeroStakeFixture);
      await myNFTContract.mintNFT(owner);
      await bheroStakeContract.depositCoinIntoHeroId(1, 1000n);
      await expect(
        bheroStakeContract.withdrawCoinFromHeroId(1, 1100n))
      .to.be.revertedWith("Amount <= heroStake[id].balance");
    });

    it("Withdraw Coin by Different Owner", async function() {
      const {owner, addr1, addr2, bcoinToken, senToken, myNFTContract, bheroStakeContract} = await loadFixture(deployBHeroStakeFixture);
      await myNFTContract.mintNFT(owner);
      await bheroStakeContract.depositCoinIntoHeroId(1, 1000n);
      await expect(
        bheroStakeContract.connect(addr1).withdrawCoinFromHeroId(1, 500n))
      .to.be.revertedWith("Must be owner of hero");
    });
  });

  describe("Stake V2", function () {
    it("V1 stake, then withdraw V2", async function() {
      const {owner, addr1, addr2, bcoinToken, senToken, myNFTContract, bheroStakeContract} = await loadFixture(deployBHeroStakeFixture);
      await myNFTContract.mintNFT(owner);
      await bheroStakeContract.depositCoinIntoHeroId(1, 1000n);
      //await bheroStakeContract.withdrawV2(bcoinToken, 1, 1500n);
      
      await expect(
        bheroStakeContract.withdrawV2(bcoinToken, 1, 1500n)
      ).to.be.revertedWith("Amount <= heroStake balance");

      await bheroStakeContract.withdrawV2(bcoinToken, 1, 500n);
      //console.log("Log:", await bheroStakeContract.getCoinBalanceV2(bcoinToken, 1));

      await expect(
        await bheroStakeContract.getCoinBalanceV2(bcoinToken, 1)
      ).to.be.equals(500);

      // await expect(
      //   await bheroStakeContract.getCoinBalanceV2(bcoinToken, 1)
      // ).to.be.equals(1500);
    });

    it("V1 stake, V2 stake, then withdraw V2", async function() {
      const {owner, addr1, addr2, bcoinToken, senToken, myNFTContract, bheroStakeContract} = await loadFixture(deployBHeroStakeFixture);
      await myNFTContract.mintNFT(owner);
      await bheroStakeContract.depositCoinIntoHeroId(1, 1000n);
      await bheroStakeContract.depositV2(bcoinToken, 1, 2000n);
      await bheroStakeContract.withdrawV2(bcoinToken, 1, 1500n);
      await expect(
        await bheroStakeContract.getCoinBalancesByHeroId(1)
      ).to.be.equals(0);
      await expect(
        await bheroStakeContract.getCoinBalanceV2(bcoinToken, 1)
      ).to.be.equals(1500);
    });

    it("V1 stake, then get balance", async function() {
      const {owner, addr1, addr2, bcoinToken, senToken, myNFTContract, bheroStakeContract} = await loadFixture(deployBHeroStakeFixture);
      await myNFTContract.mintNFT(owner);
      await bheroStakeContract.depositCoinIntoHeroId(1, 1000n);
      
      await expect(
        await bheroStakeContract.getCoinBalanceV2(bcoinToken, 1)
      ).to.be.equals(1000);
    });
  });

  describe("Time Stake", function () {
    it("weighted time stake #1", async function() {
      const {owner, addr1, addr2, bcoinToken, senToken, myNFTContract, bheroStakeContract} = await loadFixture(deployBHeroStakeFixture);
      await myNFTContract.mintNFT(owner);
      await myNFTContract.mintNFT(owner);
      await time.increaseTo(1800000000n);
      await bheroStakeContract.depositV2(bcoinToken, 1, 1900n);
      console.log("Log bheroStakeContract.getTimeStakeV2(owner): ", await bheroStakeContract.getTimeStakeV2(bcoinToken, 1));

      await time.increase(10000);
      await bheroStakeContract.depositV2(bcoinToken, 1, 100n);
      //console.log("Log bheroStakeContract.getTimeStakeV2(owner): ", await bheroStakeContract.getTimeStakeV2(bcoinToken, 2));

      await expect(
        await bheroStakeContract.getCoinBalanceV2(bcoinToken, 1)
      ).to.be.equals(2000n);
      
      await expect(
        await bheroStakeContract.getTimeStakeV2(bcoinToken, 1)
      ).to.be.equals(1800000502);
      // await expect(
      //   await bheroStakeContract.getCoinBalanceV2(bcoinToken, 1)
      // ).to.be.equals(1500);
    });

    it("weighted time stake #2", async function() {
      const {owner, addr1, addr2, bcoinToken, senToken, myNFTContract, bheroStakeContract} = await loadFixture(deployBHeroStakeFixture);
      await myNFTContract.mintNFT(owner);
      await myNFTContract.mintNFT(owner);
      await time.increaseTo(1800000000n);
      await bheroStakeContract.depositV2(bcoinToken, 1, 100n);
      //console.log("Log bheroStakeContract.getTimeStakeV2(owner): ", await bheroStakeContract.getTimeStakeV2(bcoinToken, 1));

      await time.increase(10000);
      await bheroStakeContract.depositV2(bcoinToken, 1, 1900n);
      //console.log("Log bheroStakeContract.getTimeStakeV2(owner): ", await bheroStakeContract.getTimeStakeV2(bcoinToken, 2));

      await expect(
        await bheroStakeContract.getCoinBalanceV2(bcoinToken, 1)
      ).to.be.equals(2000n);
      
      await expect(
        await bheroStakeContract.getTimeStakeV2(bcoinToken, 1)
      ).to.be.equals(1800009502);
      // await expect(
      //   await bheroStakeContract.getCoinBalanceV2(bcoinToken, 1)
      // ).to.be.equals(1500);
    });

    it("weighted time stake, stake V1 then stake V2", async function() {
      const {owner, addr1, addr2, bcoinToken, senToken, myNFTContract, bheroStakeContract} = await loadFixture(deployBHeroStakeFixture);
      await myNFTContract.mintNFT(owner);
      await myNFTContract.mintNFT(owner);
      await time.increaseTo(1800000000n);
      await bheroStakeContract.depositCoinIntoHeroId(1, 100n);
      //console.log("Log bheroStakeContract.getTimeStakeV2(owner): ", await bheroStakeContract.getTimeStakeV2(bcoinToken, 1));

      await time.increase(10000);
      await bheroStakeContract.depositV2(bcoinToken, 1, 1900n);
      //console.log("Log bheroStakeContract.getTimeStakeV2(owner): ", await bheroStakeContract.getTimeStakeV2(bcoinToken, 2));

      await expect(
        await bheroStakeContract.getCoinBalanceV2(bcoinToken, 1)
      ).to.be.equals(2000n);
      
      await expect(
        await bheroStakeContract.getTimeStakeV2(bcoinToken, 1)
      ).to.be.equals(1800009502);
      // await expect(
      //   await bheroStakeContract.getCoinBalanceV2(bcoinToken, 1)
      // ).to.be.equals(1500);
    });
  });

});