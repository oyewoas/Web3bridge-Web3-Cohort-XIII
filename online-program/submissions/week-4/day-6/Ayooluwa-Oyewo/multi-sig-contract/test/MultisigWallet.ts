import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("MultiSigWallet", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployMultiSigWalletFixture() {
    const MultiSigWallet = await hre.ethers.getContractFactory(
      "MultiSigWallet"
    );
    const [owner, ownerTwo, ownerThree, ownerFour] =
      await hre.ethers.getSigners();
    const owners = [owner.address, ownerTwo.address, ownerThree.address];
    const requiredConfirmations = 3;
    const multiSigWallet = await MultiSigWallet.deploy(
      owners,
      requiredConfirmations
    );
    await owner.sendTransaction({
      to: multiSigWallet.target,
      value: hre.ethers.parseEther("5"),
    });

    return {
      multiSigWallet,
      owner,
      ownerTwo,
      ownerFour,
      ownerThree,
      owners,
      requiredConfirmations,
    };
  }

  describe("Deployment", function () {
    it("Should set the right multiSigWallet contract", async function () {
      const {
        multiSigWallet,
        owners,
        requiredConfirmations,
        owner,
        ownerTwo,
        ownerThree,
      } = await loadFixture(deployMultiSigWalletFixture);
      expect(await multiSigWallet.transactionCount()).to.equal(0);
      expect(await multiSigWallet.requiredConfirmations()).to.equal(
        requiredConfirmations
      );
      expect((await multiSigWallet.getOwners()).length).to.deep.equal(
        owners.length
      );
      expect(await multiSigWallet.isOwner(owner.address)).to.equal(true);
      expect(await multiSigWallet.isOwner(ownerTwo.address)).to.equal(true);
      expect(await multiSigWallet.isOwner(ownerThree.address)).to.equal(true);
      expect(
        await multiSigWallet.isOwner(hre.ethers.Wallet.createRandom().address)
      ).to.equal(false);
    });
    it("Should revert if no owners are provided", async function () {
      const MultiSigWallet = await hre.ethers.getContractFactory(
        "MultiSigWallet"
      );
      await expect(
        MultiSigWallet.deploy([], 1)
      ).to.be.revertedWithCustomError(
        MultiSigWallet,
        "MultiSigWallet_OwnersRequired"
      );
    });
    it("Should revert if required confirmations are invalid", async function () {
      const MultiSigWallet = await hre.ethers.getContractFactory(
        "MultiSigWallet"
      );
      const [owner] = await hre.ethers.getSigners();
      await expect(
        MultiSigWallet.deploy([owner.address], 2)
      ).to.be.revertedWithCustomError(
        MultiSigWallet,
        "MultiSigWallet_InvalidRequiredConfirmations"
      );
    }
    );
    it("Should revert if duplicate owners are provided", async function () {
      const MultiSigWallet = await hre.ethers.getContractFactory(
        "MultiSigWallet"
      );
      const [owner] = await hre.ethers.getSigners();
      await expect(
        MultiSigWallet.deploy([owner.address, owner.address], 2)
      ).to.be.revertedWithCustomError(
        MultiSigWallet,
        "MultiSigWallet_DuplicateOwnerAddress"
      );
    });
    it(" Should revert if one of the address is a zero address", async function () {
      const MultiSigWallet = await hre.ethers.getContractFactory(
        "MultiSigWallet"
      );
      const [owner] = await hre.ethers.getSigners();
          const zeroAddress = "0x0000000000000000000000000000000000000000";

      await expect(
        MultiSigWallet.deploy([owner.address, zeroAddress], 2)
      ).to.be.revertedWithCustomError(
        MultiSigWallet,
        "MultiSigWallet_InvalidOwnerAddress"
      );
    });
    });

  describe("Submit transaction Function", function () {
    it("Should submit a transaction", async function () {
      const { multiSigWallet, owner } = await loadFixture(
        deployMultiSigWalletFixture
      );
      const destination = owner.address;

      await multiSigWallet.submitTransaction(
        destination,
        hre.ethers.parseEther("1"),
        "0x"
      );

      const eventDetails = await multiSigWallet.getTransaction(0);
      expect(eventDetails.destination).to.equal(destination);
      expect(eventDetails.value).to.equal(hre.ethers.parseEther("1"));
      expect(eventDetails.data).to.equal("0x");
      expect(eventDetails.confirmationCount).to.equal(0);
    });
    it("Should not allow scheduling the transaction if not owner", async function () {
      const { multiSigWallet, owner, ownerFour } = await loadFixture(
        deployMultiSigWalletFixture
      );
      const destination = owner.address;

      await expect(
        multiSigWallet
          .connect(ownerFour)
          .submitTransaction(destination, hre.ethers.parseEther("1"), "0x")
      ).to.be.revertedWithCustomError(
        multiSigWallet,
        "MultiSigWallet_NotAnOwner"
      );
    });
  });
  describe("Confirm Transaction", function () {
    it("Should confirm a transaction", async function () {
      const { multiSigWallet, owner, ownerTwo, ownerThree } = await loadFixture(
        deployMultiSigWalletFixture
      );
      const destination = owner.address;

      await multiSigWallet.submitTransaction(
        destination,
        hre.ethers.parseEther("1"),
        "0x"
      );
      await multiSigWallet.connect(ownerTwo).confirmTransaction(0);
      await multiSigWallet.connect(ownerThree).confirmTransaction(0);

      const eventDetails = await multiSigWallet.getTransaction(0);
      expect(eventDetails.confirmationCount).to.equal(2);
    });
    it("Should not allow confirming a transaction if not owner", async function () {
      const { multiSigWallet, ownerTwo, ownerFour } = await loadFixture(
        deployMultiSigWalletFixture
      );
      const destination = ownerTwo.address;
      await multiSigWallet.submitTransaction(
        destination,
        hre.ethers.parseEther("1"),
        "0x"
      );
      await expect(
        multiSigWallet.connect(ownerFour).confirmTransaction(0)
      ).to.be.revertedWithCustomError(
        multiSigWallet,
        "MultiSigWallet_NotAnOwner"
      );
    });

    it("Should not allow confirming a transaction that does not exist", async function () {
      const { multiSigWallet, owner } = await loadFixture(
        deployMultiSigWalletFixture
      );
      await expect(
        multiSigWallet.connect(owner).confirmTransaction(1)
      ).to.be.revertedWithCustomError(
        multiSigWallet,
        "MultiSigWallet_TransactionDoesNotExist"
      );
    });
    it("Should not allow confirming a transaction that is already confirmed", async function () {
      const { multiSigWallet, owner, ownerTwo } = await loadFixture(
        deployMultiSigWalletFixture
      );
      const destination = owner.address;

      await multiSigWallet.submitTransaction(
        destination,
        hre.ethers.parseEther("1"),
        "0x"
      );
      await multiSigWallet.connect(ownerTwo).confirmTransaction(0);
      await expect(
        multiSigWallet.connect(ownerTwo).confirmTransaction(0)
      ).to.be.revertedWithCustomError(
        multiSigWallet,
        "MultiSigWallet_TransactionAlreadyConfirmed"
      );
    });
  });

  describe("Revoke Confirmation", function () {
    it("Should revoke a confirmation", async function () {
      const { multiSigWallet, owner, ownerTwo, ownerThree } = await loadFixture(
        deployMultiSigWalletFixture
      );
      const destination = owner.address;

      await multiSigWallet.submitTransaction(
        destination,
        hre.ethers.parseEther("1"),
        "0x"
      );
      await multiSigWallet.connect(ownerTwo).confirmTransaction(0);
      await multiSigWallet.connect(ownerThree).confirmTransaction(0);
      const eventDetailsOne = await multiSigWallet.getTransaction(0);
      expect(eventDetailsOne.confirmationCount).to.equal(2);
      await multiSigWallet.connect(ownerTwo).revokeConfirmation(0);
      const eventDetailsTwo = await multiSigWallet.getTransaction(0);
      expect(eventDetailsTwo.confirmationCount).to.equal(1);
    });
    it("Should not allow revoking confirmation if not owner", async function () {
      const { multiSigWallet, ownerFour } = await loadFixture(
        deployMultiSigWalletFixture
      );
      await expect(
        multiSigWallet.connect(ownerFour).revokeConfirmation(0)
      ).to.be.revertedWithCustomError(
        multiSigWallet,
        "MultiSigWallet_NotAnOwner"
      );
    });
    it("Should not allow revoking confirmation for a transaction that does not exist", async function () {
      const { multiSigWallet, owner } = await loadFixture(
        deployMultiSigWalletFixture
      );
      await expect(
        multiSigWallet.connect(owner).revokeConfirmation(1)
      ).to.be.revertedWithCustomError(
        multiSigWallet,
        "MultiSigWallet_TransactionDoesNotExist"
      );
    });
    it("Should not allow revoking confirmation for a transaction that is not confirmed by the owner", async function () {
      const { multiSigWallet, owner, ownerTwo } = await loadFixture(
        deployMultiSigWalletFixture
      );
      const destination = owner.address;
      await multiSigWallet.submitTransaction(
        destination,
        hre.ethers.parseEther("1"),
        "0x"
      );
      await multiSigWallet.connect(ownerTwo).confirmTransaction(0);
      await expect(
        multiSigWallet.connect(owner).revokeConfirmation(0)
      ).to.be.revertedWithCustomError(
        multiSigWallet,
        "MultiSigWallet_TransactionNotConfirmed"
      );
    });
  });

  describe("Execute Transaction", function () {
    it("Should execute a transaction", async function () {
      const { multiSigWallet, owner, ownerTwo, ownerThree } = await loadFixture(
        deployMultiSigWalletFixture
      );
      const destination = owner.address;

      await multiSigWallet.submitTransaction(
        destination,
        hre.ethers.parseEther("1"),
        "0x"
      );
      await multiSigWallet.connect(ownerTwo).confirmTransaction(0);
      await multiSigWallet.connect(ownerThree).confirmTransaction(0);
      await multiSigWallet.confirmTransaction(0);

      await expect(multiSigWallet.executeTransaction(0))
        .to.emit(multiSigWallet, "TransactionExecuted")
        .withArgs(0);

      const eventDetails = await multiSigWallet.getTransaction(0);
      expect(eventDetails.executed).to.equal(true);
    });
    it("Should not allow executing a transaction if not enough confirmations", async function () {
      const { multiSigWallet, owner } = await loadFixture(
        deployMultiSigWalletFixture
      );
      const destination = owner.address;

      await multiSigWallet.submitTransaction(
        destination,
        hre.ethers.parseEther("1"),
        "0x"
      );
      await expect(
        multiSigWallet.executeTransaction(0)
      ).to.be.revertedWithCustomError(
        multiSigWallet,
        "MultiSigWallet_NotEnoughConfirmations"
      );
    });
    it("Should not allow executing a transaction that does not exist", async function () {
      const { multiSigWallet, owner } = await loadFixture(
        deployMultiSigWalletFixture
      );
      await expect(
        multiSigWallet.executeTransaction(1)
      ).to.be.revertedWithCustomError(
        multiSigWallet,
        "MultiSigWallet_TransactionDoesNotExist"
      );
    });
    it("Should not allow executing a transaction that has already been executed", async function () {
      const { multiSigWallet, owner, ownerTwo, ownerThree } = await loadFixture(
        deployMultiSigWalletFixture
      );
      const destination = owner.address;

      await multiSigWallet.submitTransaction(
        destination,
        hre.ethers.parseEther("1"),
        "0x"
      );
      await multiSigWallet.connect(ownerTwo).confirmTransaction(0);
      await multiSigWallet.connect(ownerThree).confirmTransaction(0);
      await multiSigWallet.confirmTransaction(0);

      await multiSigWallet.executeTransaction(0);

      await expect(
        multiSigWallet.executeTransaction(0)
      ).to.be.revertedWithCustomError(
        multiSigWallet,
        "MultiSigWallet_TransactionAlreadyExecuted"
      );
    });
    it("Should not allow executing a transaction if the execution fails", async function () {
      const { multiSigWallet, owner, ownerTwo, ownerThree } = await loadFixture(
        deployMultiSigWalletFixture
      );
      const destination = owner.address;

      await hre.network.provider.send("hardhat_setBalance", [
        multiSigWallet.target, // or .address in Ethers v5
        "0x0", // balance in hex
      ]);
      await multiSigWallet.submitTransaction(
        destination,
        hre.ethers.parseEther("1"),
        "0x"
      );
      await multiSigWallet.connect(ownerTwo).confirmTransaction(0);
      await multiSigWallet.connect(ownerThree).confirmTransaction(0);
      await multiSigWallet.confirmTransaction(0);

      await expect(
        multiSigWallet.executeTransaction(0)
      ).to.be.revertedWithCustomError(
        multiSigWallet,
        "MultiSigWallet_TransactionExecutionFailed"
      );
    });
  });

  describe("Getters", function () {
    it("Should return the correct owners", async function () {
      const { multiSigWallet, owners } = await loadFixture(
        deployMultiSigWalletFixture
      );
      const contractOwners = await multiSigWallet.getOwners();
      expect(contractOwners).to.deep.equal(owners);
    });

    it("Should return the correct transaction count", async function () {
      const { multiSigWallet } = await loadFixture(deployMultiSigWalletFixture);
      expect(await multiSigWallet.getTransactionCount()).to.equal(0);
    });

    it("Should return transactions", async function () {
      const { multiSigWallet, owner } = await loadFixture(
        deployMultiSigWalletFixture
      );
      await multiSigWallet.submitTransaction(
        owner.address,
        hre.ethers.parseEther("1"),
        "0x"
      );
      const transaction = await multiSigWallet.getTransaction(0);
      expect(transaction.destination).to.equal(owner.address);
      expect(transaction.value).to.equal(hre.ethers.parseEther("1"));
      expect(transaction.data).to.equal("0x");
      expect(transaction.confirmationCount).to.equal(0);
      expect(transaction.executed).to.equal(false);
    });
  });
});
