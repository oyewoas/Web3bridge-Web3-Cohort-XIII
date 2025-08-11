import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { erc20 } from "../typechain-types/@openzeppelin/contracts/token";

describe("PiggyBank", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployPiggyBank() {
    const [deployer, userAccountOne, userAccountTwo] =
      await hre.ethers.getSigners();

    const PiggyBank = await hre.ethers.getContractFactory("PiggyBank");
    const Erc20 = await hre.ethers.getContractFactory("MockERC20");
    const PiggyBankFactory = await hre.ethers.getContractFactory(
      "PiggyBankFactory"
    );
    const piggyBankFactory = await PiggyBankFactory.deploy();

    const erc20 = await Erc20.deploy(
      "Mock Token",
      "MTK",
      hre.ethers.parseEther("1000000")
    );
    // mint
    await erc20.mint(userAccountOne.address, hre.ethers.parseEther("10000"));

    const piggyBankERC20 = await PiggyBank.deploy(
      userAccountOne.address,
      hre.ethers.parseEther("1000"),
      erc20.target,
      30,
      piggyBankFactory.admin(),
      piggyBankFactory.target
    );
    const piggyBankEther = await PiggyBank.deploy(
      userAccountOne.address,
      hre.ethers.parseEther("1000"),
      hre.ethers.ZeroAddress,
      30,
      piggyBankFactory.admin(),
      piggyBankFactory.target
    );

    return {
      piggyBankERC20,
      userAccountTwo,
      piggyBankEther,
      deployer,
      userAccountOne,
      erc20,
      piggyBankFactory,
    };
  }

  describe("Deployment", function () {
    it("Should deploy it", async function () {
      const {
        piggyBankERC20,
        erc20,
        piggyBankEther,
        deployer,
        piggyBankFactory,
      } = await loadFixture(deployPiggyBank);

      expect(await piggyBankERC20.factoryAdmin()).to.equal(deployer.address);
      expect(await piggyBankERC20.factory()).to.equal(piggyBankFactory.target);
      expect(await piggyBankEther.factory()).to.equal(piggyBankFactory.target);
      expect((await piggyBankERC20.savingsPlan()).tokenAddress).to.equal(
        erc20.target
      );
      expect((await piggyBankERC20.savingsPlan()).lockPeriod).to.equal(30);
      expect((await piggyBankERC20.savingsPlan()).balance).to.equal(
        hre.ethers.parseEther("0")
      );
      expect((await piggyBankERC20.savingsPlan()).targetAmount).to.equal(
        hre.ethers.parseEther("1000")
      );
    });
  });
  describe("deposit ERC20", function () {
    it("Should deposit ERC20 tokens", async function () {
      const { piggyBankERC20, userAccountOne, erc20 } = await loadFixture(
        deployPiggyBank
      );

      await erc20
        .connect(userAccountOne)
        .approve(piggyBankERC20.target, hre.ethers.parseEther("1000"));
      expect(
        await piggyBankERC20
          .connect(userAccountOne)
          .depositERC20(hre.ethers.parseEther("1000"))
      )
        .to.emit(piggyBankERC20, "SavingsPlanFunded")
        .withArgs(userAccountOne.address, hre.ethers.parseEther("1000"));
      expect((await piggyBankERC20.savingsPlan()).balance).to.equal(
        hre.ethers.parseEther("1000")
      );
      expect(await erc20.balanceOf(userAccountOne.address)).to.equal(
        hre.ethers.parseEther("9000")
      );
    });
    it("Should not allow deposit if not enough balance", async function () {
      const { piggyBankERC20, userAccountOne, erc20 } = await loadFixture(
        deployPiggyBank
      );

      await erc20
        .connect(userAccountOne)
        .approve(piggyBankERC20.target, hre.ethers.parseEther("1000"));
      await expect(
        piggyBankERC20
          .connect(userAccountOne)
          .depositERC20(hre.ethers.parseEther("11000"))
      ).to.be.revertedWithCustomError(
        piggyBankERC20,
        "PiggyBank__InsufficientFunds"
      );
    });
    it("Should not allow deposit if savings plan is inactive", async function () {
      const { piggyBankERC20, userAccountOne, erc20 } = await loadFixture(
        deployPiggyBank
      );

      await erc20
        .connect(userAccountOne)
        .approve(piggyBankERC20.target, hre.ethers.parseEther("1000"));
      await piggyBankERC20
        .connect(userAccountOne)
        .depositERC20(hre.ethers.parseEther("1000"));
      await piggyBankERC20.connect(userAccountOne).setSavingsPlanInactive();
      await expect(
        piggyBankERC20
          .connect(userAccountOne)
          .depositERC20(hre.ethers.parseEther("1000"))
      ).to.be.revertedWithCustomError(
        piggyBankERC20,
        "PiggyBank__SavingsPlanInactive"
      );
    });

    it("Should not allow sending ether if plan only accepts ERC20", async function () {
      const { piggyBankERC20, userAccountOne } = await loadFixture(
        deployPiggyBank
      );

      await expect(
        piggyBankERC20
          .connect(userAccountOne)
          .depositETH({ value: hre.ethers.parseEther("1") })
      ).to.be.revertedWithCustomError(
        piggyBankERC20,
        "PiggyBank__CanOnlyReceiveERC20"
      );
    });
    it("Should not allow deposit if zero value", async function () {
      const { piggyBankERC20, userAccountOne } = await loadFixture(
        deployPiggyBank
      );

      await expect(
        piggyBankERC20
          .connect(userAccountOne)
          .depositETH({ value: hre.ethers.parseEther("0") })
      ).to.be.revertedWithCustomError(piggyBankERC20, "PiggyBank__ZeroValue");
    });
  });
  describe("deposit ETH", function () {
    it("Should deposit ETH", async function () {
      const { piggyBankEther, userAccountOne } = await loadFixture(
        deployPiggyBank
      );

      const depositAmount = hre.ethers.parseEther("1");
      await expect(
        piggyBankEther
          .connect(userAccountOne)
          .depositETH({ value: depositAmount })
      )
        .to.emit(piggyBankEther, "SavingsPlanFunded")
        .withArgs(userAccountOne.address, depositAmount);
      expect((await piggyBankEther.savingsPlan()).balance).to.equal(
        depositAmount
      );
    });
    it("Should not allow sending ERC20 tokens if plan only accepts ETH", async function () {
      const { piggyBankEther, userAccountOne, erc20 } = await loadFixture(
        deployPiggyBank
      );

      await erc20
        .connect(userAccountOne)
        .approve(piggyBankEther.target, hre.ethers.parseEther("1000"));
      await expect(
        piggyBankEther
          .connect(userAccountOne)
          .depositERC20(hre.ethers.parseEther("1000"))
      ).to.be.revertedWithCustomError(
        piggyBankEther,
        "PiggyBank__CanOnlyReceiveETH"
      );
    });
    it("Should not allow deposit if zero value", async function () {
      const { piggyBankEther, userAccountOne } = await loadFixture(
        deployPiggyBank
      );

      await expect(
        piggyBankEther
          .connect(userAccountOne)
          .depositETH({ value: hre.ethers.parseEther("0") })
      ).to.be.revertedWithCustomError(piggyBankEther, "PiggyBank__ZeroValue");
    });
    it("Should not allow deposit if savings plan is inactive", async function () {
      const { piggyBankEther, userAccountOne } = await loadFixture(
        deployPiggyBank
      );

      await piggyBankEther
        .connect(userAccountOne)
        .depositETH({ value: hre.ethers.parseEther("1") });
      await piggyBankEther.connect(userAccountOne).setSavingsPlanInactive();
      await expect(
        piggyBankEther
          .connect(userAccountOne)
          .depositETH({ value: hre.ethers.parseEther("1") })
      ).to.be.revertedWithCustomError(
        piggyBankEther,
        "PiggyBank__SavingsPlanInactive"
      );
    });
  });
  describe("withdraw", function () {
    it("Should allow owner to withdraw funds after lock period", async function () {
      const { piggyBankEther, piggyBankERC20, userAccountOne, erc20 } =
        await loadFixture(deployPiggyBank);
      await time.increase(100);
      await piggyBankEther
        .connect(userAccountOne)
        .depositETH({ value: hre.ethers.parseEther("1") });
      await erc20
        .connect(userAccountOne)
        .approve(piggyBankERC20.target, hre.ethers.parseEther("1000"));

      await piggyBankERC20
        .connect(userAccountOne)
        .depositERC20(hre.ethers.parseEther("10"));
      expect(await erc20.balanceOf(userAccountOne.address)).to.equal(
        hre.ethers.parseEther("9990")
      );
      await expect(
        piggyBankEther
          .connect(userAccountOne)
          .withdraw(hre.ethers.parseEther("1"))
      )
        .to.emit(piggyBankEther, "SavingsPlanWithdrawn")
        .withArgs(userAccountOne.address, hre.ethers.parseEther("1"));
      await expect(
        piggyBankERC20
          .connect(userAccountOne)
          .withdraw(hre.ethers.parseEther("9"))
      )
        .to.emit(piggyBankERC20, "SavingsPlanWithdrawn")
        .withArgs(userAccountOne.address, hre.ethers.parseEther("9"));
      expect((await piggyBankEther.savingsPlan()).balance).to.equal(0);
      expect((await piggyBankERC20.savingsPlan()).balance).to.equal(
        hre.ethers.parseEther("1")
      );
      expect(await erc20.balanceOf(userAccountOne.address)).to.equal(
        hre.ethers.parseEther("9999")
      );
    });
    it("Should allow owner to withdraw funds before lock period", async function () {
      const { piggyBankEther, piggyBankERC20, userAccountOne, erc20 } =
        await loadFixture(deployPiggyBank);
      await piggyBankEther
        .connect(userAccountOne)
        .depositETH({ value: hre.ethers.parseEther("1") });
      await erc20
        .connect(userAccountOne)
        .approve(piggyBankERC20.target, hre.ethers.parseEther("1000"));

      await piggyBankERC20
        .connect(userAccountOne)
        .depositERC20(hre.ethers.parseEther("10"));
      expect(await erc20.balanceOf(userAccountOne.address)).to.equal(
        hre.ethers.parseEther("9990")
      );
      await expect(
        piggyBankEther
          .connect(userAccountOne)
          .withdraw(hre.ethers.parseEther("1"))
      )
        .to.emit(piggyBankEther, "SavingsPlanWithdrawn")
        .withArgs(userAccountOne.address, hre.ethers.parseEther("1"));
      await expect(
        piggyBankERC20
          .connect(userAccountOne)
          .withdraw(hre.ethers.parseEther("9"))
      )
        .to.emit(piggyBankERC20, "SavingsPlanWithdrawn")
        .withArgs(userAccountOne.address, hre.ethers.parseEther("9"));
      expect((await piggyBankEther.savingsPlan()).balance).to.equal(0);
      expect((await piggyBankERC20.savingsPlan()).balance).to.equal(
        hre.ethers.parseEther("1")
      );
      expect(await erc20.balanceOf(userAccountOne.address)).to.equal(
        hre.ethers.parseEther("9998.73")
      );

      // expect fee sent to factory admin
      expect(await erc20.balanceOf(piggyBankERC20.factoryAdmin())).to.equal(
        hre.ethers.parseEther("1000000.27")
      );
    });
    it("Should not allow owner to withdraw more than balance", async function () {
      const { piggyBankEther, userAccountOne } = await loadFixture(
        deployPiggyBank
      );
      await piggyBankEther
        .connect(userAccountOne)
        .depositETH({ value: hre.ethers.parseEther("1") });
      await expect(
        piggyBankEther
          .connect(userAccountOne)
          .withdraw(hre.ethers.parseEther("2"))
      ).to.be.revertedWithCustomError(
        piggyBankEther,
        "PiggyBank__InsufficientFunds"
      );
    });
    it("Should not allow non-owner to withdraw funds", async function () {
      const { piggyBankEther, userAccountOne, userAccountTwo } =
        await loadFixture(deployPiggyBank);
      await piggyBankEther
        .connect(userAccountOne)
        .depositETH({ value: hre.ethers.parseEther("1") });
      await expect(
        piggyBankEther
          .connect(userAccountTwo)
          .withdraw(hre.ethers.parseEther("1"))
      ).to.be.revertedWithCustomError(
        piggyBankEther,
        "PiggyBank__UnauthorizedAccess"
      );
    });
  });

  describe("WithdrawAll", function () {
    it("Should allow owner to withdraw all funds", async function () {
      const { piggyBankEther, userAccountOne } = await loadFixture(
        deployPiggyBank
      );
      await piggyBankEther
        .connect(userAccountOne)
        .depositETH({ value: hre.ethers.parseEther("1") });
      await expect(piggyBankEther.connect(userAccountOne).withdrawAll())
        .to.emit(piggyBankEther, "SavingsPlanWithdrawn")
        .withArgs(userAccountOne.address, hre.ethers.parseEther("1"));
    });
  });
  describe("Set Savings Plan Inactive", function () {
    it("Should allow owner to set savings plan inactive", async function () {
      const { piggyBankEther, userAccountOne } = await loadFixture(
        deployPiggyBank
      );
      await piggyBankEther.connect(userAccountOne).setSavingsPlanInactive();
      expect((await piggyBankEther.savingsPlan()).status).to.equal(0);
    });
    it("Should not allow non-owner to set savings plan inactive", async function () {
      const { piggyBankEther, userAccountOne, userAccountTwo } =
        await loadFixture(deployPiggyBank);
      await expect(
        piggyBankEther.connect(userAccountTwo).setSavingsPlanInactive()
      ).to.be.revertedWithCustomError(
        piggyBankEther,
        "PiggyBank__UnauthorizedAccess"
      );
    });
  });
});
