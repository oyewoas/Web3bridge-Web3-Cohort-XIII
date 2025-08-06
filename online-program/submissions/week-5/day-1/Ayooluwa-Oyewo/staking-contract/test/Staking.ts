import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre from "hardhat";

describe("Staking", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployOneYearLockFixture() {
    const [owner, otherAccount] = await hre.ethers.getSigners();
    const Staking = await hre.ethers.getContractFactory("Staking");
    const TokenA = await hre.ethers.getContractFactory("TokenA");
    const TokenB = await hre.ethers.getContractFactory("TokenB");

    const tokenA = await TokenA.deploy(hre.ethers.parseEther("10000000000"));
    await tokenA.transfer(otherAccount.address, hre.ethers.parseEther("1000"));

    const tokenB = await TokenB.deploy();
    const lockPeriod = 30 * 24 * 60 * 60; // 30 days

    const staking = await Staking.deploy(
      tokenA.target,
      tokenB.target,
      lockPeriod
    );
    await tokenB.setMinter(staking.target, true); // Set staking contract as minter

    return {
      staking,
      tokenA,
      Staking,
      tokenB,
      lockPeriod,
      owner,
      otherAccount,
    };
  }

  describe("Deployment", function () {
    it("Should deploy staking token", async function () {
      const { staking, tokenA, tokenB, lockPeriod } = await loadFixture(
        deployOneYearLockFixture
      );

      expect(await staking.tokenA()).to.equal(tokenA);
      expect(await staking.tokenB()).to.equal(tokenB);
      expect(await staking.lockPeriod()).to.equal(lockPeriod);
    });
    it("Should not deploy with zero address", async function () {
      const { tokenA, tokenB, Staking } = await loadFixture(
        deployOneYearLockFixture
      );

      await expect(
        Staking.deploy(tokenA.target, tokenB.target, 0)
      ).to.be.revertedWithCustomError(Staking, "Staking_NoLockPeriodSet");
    });
    it("Should not deploy with zero address for tokenA", async function () {
      const { tokenB, Staking } = await loadFixture(deployOneYearLockFixture);

      await expect(
        Staking.deploy(hre.ethers.ZeroAddress, tokenB.target, 30 * 24 * 60 * 60)
      ).to.be.revertedWithCustomError(
        Staking,
        "Staking_StakingTokenAddressNotSet"
      );
    });
    it("Should not deploy with zero address for tokenB", async function () {
      const { tokenA, Staking } = await loadFixture(deployOneYearLockFixture);

      await expect(
        Staking.deploy(tokenA.target, hre.ethers.ZeroAddress, 30 * 24 * 60 * 60)
      ).to.be.revertedWithCustomError(
        Staking,
        "Staking_RewardTokenAddressNotSet"
      );
    });
    it("Should emit StakingDeployed event", async function () {
      const { staking, tokenA, tokenB, lockPeriod } = await loadFixture(
        deployOneYearLockFixture
      );
      await expect(staking.deploymentTransaction())
        .to.emit(staking, "StakingDeployed")
        .withArgs(tokenA.target, tokenB.target, lockPeriod);
    });
  });

  describe("Stake Function", function () {
    it("Should not allow staking with zero amount", async function () {
      const { staking, otherAccount } = await loadFixture(
        deployOneYearLockFixture
      );
      await expect(
        staking.connect(otherAccount).stake(0)
      ).to.be.revertedWithCustomError(staking, "Staking_ZeroAmount");
    });

    it("Should not allow staking more than balance", async function () {
      const { staking, tokenA, otherAccount } = await loadFixture(
        deployOneYearLockFixture
      );

      // otherAccount has only 1000 tokenA — try to stake more than that
      await tokenA
        .connect(otherAccount)
        .approve(staking.target, hre.ethers.parseEther("2000"));

      await expect(
        staking.connect(otherAccount).stake(hre.ethers.parseEther("2000"))
      ).to.be.revertedWithCustomError(staking, "Staking_NotEnoughTokens");
    });
    it("Should not allow staking if already staked", async function () {
      const { staking, tokenA, otherAccount } = await loadFixture(
        deployOneYearLockFixture
      );

      await tokenA
        .connect(otherAccount)
        .approve(staking.target, hre.ethers.parseEther("100"));
      await staking.connect(otherAccount).stake(hre.ethers.parseEther("100"));

      // Try staking again
      await tokenA
        .connect(otherAccount)
        .approve(staking.target, hre.ethers.parseEther("100"));
      await expect(
        staking.connect(otherAccount).stake(hre.ethers.parseEther("100"))
      ).to.be.revertedWithCustomError(staking, "Staking_AlreadyStaked");
    });
    it("Should allow staking and emit event", async function () {
      const { staking, tokenA, otherAccount } = await loadFixture(
        deployOneYearLockFixture
      );

      await tokenA
        .connect(otherAccount)
        .approve(staking.target, hre.ethers.parseEther("100"));

      await expect(
        staking.connect(otherAccount).stake(hre.ethers.parseEther("100"))
      )
        .to.emit(staking, "Staked")
        .withArgs(otherAccount.address, hre.ethers.parseEther("100"));
    });
  });

  describe("Unstake Function", function () {
    it("Should not allow unstaking with zero amount", async function () {
      const { staking, otherAccount } = await loadFixture(
        deployOneYearLockFixture
      );
      await expect(
        staking.connect(otherAccount).unstake(0)
      ).to.be.revertedWithCustomError(staking, "Staking_ZeroAmount");
    });
    it("Should not allow unstaking if not staked", async function () {
      const { staking, otherAccount } = await loadFixture(
        deployOneYearLockFixture
      );

      await expect(
        staking.connect(otherAccount).unstake(hre.ethers.parseEther("100"))
      ).to.be.revertedWithCustomError(staking, "Staking_NotStaked");
    });
    it("Should not allow unstaking more than staked amount", async function () {
      const { staking, tokenA, otherAccount } = await loadFixture(
        deployOneYearLockFixture
      );

      await tokenA
        .connect(otherAccount)
        .approve(staking.target, hre.ethers.parseEther("100"));
      await staking.connect(otherAccount).stake(hre.ethers.parseEther("100"));

      await expect(
        staking.connect(otherAccount).unstake(hre.ethers.parseEther("200"))
      ).to.be.revertedWithCustomError(staking, "Staking_InsufficientBalance");
    });
    it("Should not allow unstaking before lock period", async function () {
      const { staking, tokenA, otherAccount, lockPeriod } = await loadFixture(
        deployOneYearLockFixture
      );

      await tokenA
        .connect(otherAccount)
        .approve(staking.target, hre.ethers.parseEther("100"));
      await staking.connect(otherAccount).stake(hre.ethers.parseEther("100"));

      // Try to unstake before lock period
      await expect(
        staking.connect(otherAccount).unstake(hre.ethers.parseEther("100"))
      ).to.be.revertedWithCustomError(staking, "Staking_LockPeriodNotOver");
    });
    it("Should allow unstaking after lock period and emit event", async function () {
      const { staking, tokenA, otherAccount, lockPeriod } = await loadFixture(
        deployOneYearLockFixture
      );

      await tokenA
        .connect(otherAccount)
        .approve(staking.target, hre.ethers.parseEther("100"));
      await staking.connect(otherAccount).stake(hre.ethers.parseEther("100"));

      // Fast forward time to unlock period
      await time.increase(lockPeriod + 1);

      await expect(
        staking.connect(otherAccount).unstake(hre.ethers.parseEther("100"))
      )
        .to.emit(staking, "Unstaked")
        .withArgs(otherAccount.address, hre.ethers.parseEther("100"));
    });
  });

  describe("Getter Functions", function () {
    it("Should return correct stake info", async function () {
      const { staking, tokenA, otherAccount } = await loadFixture(
        deployOneYearLockFixture
      );

      await tokenA
        .connect(otherAccount)
        .approve(staking.target, hre.ethers.parseEther("100"));
      await staking.connect(otherAccount).stake(hre.ethers.parseEther("100"));

      const stakeInfo = await staking.getStakeInfo(otherAccount.address);
      expect(stakeInfo.amount).to.equal(hre.ethers.parseEther("100"));
      expect(stakeInfo.unlockTime).to.be.gt(0); // Should be set to current time + lock period
    });
  });
});
