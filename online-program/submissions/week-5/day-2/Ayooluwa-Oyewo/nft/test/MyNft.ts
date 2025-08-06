import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("MyNft", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployMyNftFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await hre.ethers.getSigners();

    const MyNft = await hre.ethers.getContractFactory("MyNft");
    const myNft = await MyNft.deploy();

    return { myNft, owner, otherAccount };
  }

  describe("Deployment", function () {
    it("Should deploy the contract", async function () {
      const { myNft, owner } = await loadFixture(deployMyNftFixture);

      expect(await myNft.name()).to.equal("MyNft");
      expect(await myNft.symbol()).to.equal("MNFT");
      expect(await myNft.owner()).to.equal(owner.address);
    });
  });

  describe("Minting", function () {
    it("Should mint an NFT", async function () {
      const { myNft, owner } = await loadFixture(deployMyNftFixture);
      const tokenId = await myNft.getNextTokenId();
      expect(tokenId).to.equal(0);
      const tokenURI = "https://example.com/token/1";
      const tx = await myNft.mint(owner.address, tokenURI);
      await expect(tx)
        .to.emit(myNft, "NftMinted")
        .withArgs(0, owner.address, tokenURI);
      expect(await myNft.ownerOf(tokenId)).to.equal(owner.address);
      expect(await myNft.tokenURI(tokenId)).to.equal(tokenURI);
      expect(await myNft.getNextTokenId()).to.equal(1);
    });
    it("Should allow another account to mint an NFT", async function () {
      const { myNft, owner, otherAccount } = await loadFixture(
        deployMyNftFixture
      );
      expect(await myNft.getNextTokenId()).to.equal(0);
      const tokenURI = "https://example.com/token/1";

      // Mint first NFT to owner
      await myNft.mint(owner.address, tokenURI);
      expect(await myNft.getNextTokenId()).to.equal(1);

      // Mint second NFT to otherAccount
      const tx = await myNft.mint(otherAccount.address, tokenURI);
      await expect(tx)
        .to.emit(myNft, "NftMinted")
        .withArgs(1, otherAccount.address, tokenURI);

      // Check the second NFT (token ID 1)
      expect(await myNft.ownerOf(1)).to.equal(otherAccount.address);
      expect(await myNft.tokenURI(1)).to.equal(tokenURI);
      expect(await myNft.getNextTokenId()).to.equal(2);
    });

    it("Should revert if the tokenURI is the empty string", async function () {
      const { myNft, owner } = await loadFixture(deployMyNftFixture);
      const tokenURI = "";
      await expect(
        myNft.mint(owner.address, tokenURI)
      ).to.be.revertedWithCustomError(myNft, "MyNft_NoTokenURI");
    });
    it("Should revert if the recipient is the zero address", async function () {
      const { myNft } = await loadFixture(deployMyNftFixture);
      const tokenURI = "https://example.com/token/1";
      await expect(
        myNft.mint(hre.ethers.ZeroAddress, tokenURI)
      ).to.be.revertedWithCustomError(myNft, "MyNft_NoRecipient");
    });
  });

  describe("Burning", function () {
    it("Should burn an NFT", async function () {
      const { myNft, owner } = await loadFixture(deployMyNftFixture);
      const tokenId = await myNft.getNextTokenId();
      await myNft.mint(owner.address, "https://example.com/token/1");
      expect(await myNft.ownerOf(tokenId)).to.equal(owner.address);
      expect(await myNft.tokenURI(tokenId)).to.equal(
        "https://example.com/token/1"
      );
      expect(await myNft.balanceOf(owner.address)).to.equal(1);

      const burnTx = await myNft.burn(tokenId);
      await expect(burnTx).to.emit(myNft, "NftBurned").withArgs(tokenId);
      expect(await myNft.balanceOf(owner.address)).to.equal(0);
    });
  });
});
