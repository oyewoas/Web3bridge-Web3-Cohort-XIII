import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("PiggyBankFactory", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployPiggyBankFactory() {
    const [deployer, userAccountOne] = await hre.ethers.getSigners();

    const PiggyBankFactory = await hre.ethers.getContractFactory("PiggyBankFactory");
    const piggyBankFactory = await PiggyBankFactory.deploy();
    const Erc20 = await hre.ethers.getContractFactory("MockERC20");
    const erc20 = await Erc20.deploy("Mock Token", "MTK", hre.ethers.parseEther("1000000"));

    return { piggyBankFactory, deployer, userAccountOne, erc20 };
  }


  describe("Deployment", function () {
    it("Should set the right admin", async function () {
      const { piggyBankFactory, deployer } = await loadFixture(deployPiggyBankFactory);

      expect(await piggyBankFactory.admin()).to.equal(deployer.address);
      expect(await piggyBankFactory.pfGetPiggyBanksCount()).to.equal(0);
    });
  });
  describe("createPiggyBank", function () {
    it("Should create a new piggy bank to receive erc20 tokens", async function () {
      const { piggyBankFactory, deployer, userAccountOne, erc20 } = await loadFixture(deployPiggyBankFactory);

      // Create a new piggy bank
      const piggyBankAddress = await piggyBankFactory.connect(userAccountOne).createPiggyBank.staticCall(1000, erc20.target, 30);
      expect(await piggyBankFactory.connect(userAccountOne).createPiggyBank(1000, erc20.target, 30)).to.emit(piggyBankFactory, "PiggyBankCreated").withArgs(userAccountOne.address, piggyBankAddress);
      const piggyBank = await hre.ethers.getContractAt("PiggyBank", piggyBankAddress);
        expect(await piggyBankFactory.pfGetPiggyBanksCount()).to.equal(1);
        expect(await piggyBankFactory.pfGetUserSavingsCount(userAccountOne.address)).to.equal(1);
        expect(await piggyBankFactory.pfGetUserSavingsAccounts(userAccountOne.address)).to.include(piggyBankAddress);
        expect(await piggyBankFactory.pfGetSavingsBalance(piggyBankAddress)).to.equal(0);
        expect(await piggyBank.factoryAdmin()).to.equal(deployer.address);
        const savingsPlan = await piggyBank.savingsPlan();
        expect(savingsPlan.owner).to.equal(userAccountOne.address);
        expect(savingsPlan.tokenAddress).to.equal(erc20.target);
    });
  });

  describe("Getters", function () {
    it("Should get all piggy banks", async function () {
      const { piggyBankFactory, userAccountOne, erc20 } = await loadFixture(deployPiggyBankFactory);
      await piggyBankFactory.connect(userAccountOne).createPiggyBank(1000, erc20.target, 30);
      expect(await piggyBankFactory.pfGetPiggyBanksCount()).to.equal(1);
    });
    it("Should get user savings accounts", async function () {
        const { piggyBankFactory, userAccountOne, erc20 } = await loadFixture(deployPiggyBankFactory);
        await piggyBankFactory.connect(userAccountOne).createPiggyBank(1000, erc20.target, 30);
        const savingsAccounts = await piggyBankFactory.pfGetUserSavingsAccounts(userAccountOne.address);
        expect(savingsAccounts).to.have.lengthOf(1);
      });
    it("Should get savings balance", async function () {
        const { piggyBankFactory, userAccountOne, erc20 } = await loadFixture(deployPiggyBankFactory);
        const piggyBankAddress = await piggyBankFactory.connect(userAccountOne).createPiggyBank.staticCall(1000, erc20.target, 30);
        await piggyBankFactory.connect(userAccountOne).createPiggyBank(1000, erc20.target, 30);
        expect(await piggyBankFactory.pfGetSavingsBalance(piggyBankAddress)).to.equal(0);
    });
    it("Should get user savings lock period", async function () {
        const { piggyBankFactory, userAccountOne, erc20 } = await loadFixture(deployPiggyBankFactory);
        const piggyBankAddress = await piggyBankFactory.connect(userAccountOne).createPiggyBank.staticCall(1000, erc20.target, 30);
        await piggyBankFactory.connect(userAccountOne).createPiggyBank(1000, erc20.target, 30);
        expect(await piggyBankFactory.pfGetUserSavingsLockPeriod(userAccountOne.address, piggyBankAddress)).to.equal(30);
    });
    it("Should get user savings count", async function () {
        const { piggyBankFactory, userAccountOne, erc20 } = await loadFixture(deployPiggyBankFactory);
        await piggyBankFactory.connect(userAccountOne).createPiggyBank(1000, erc20.target, 30);
        expect(await piggyBankFactory.pfGetUserSavingsCount(userAccountOne.address)).to.equal(1);
    });
});
});
