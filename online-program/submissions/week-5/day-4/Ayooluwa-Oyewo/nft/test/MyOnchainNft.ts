import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("MyOnChainNft", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployMyNftFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await hre.ethers.getSigners();

    const MyOnChainNft = await hre.ethers.getContractFactory("MyOnChainNft");
    const myNft = await MyOnChainNft.deploy();

    return { myNft, owner, otherAccount };
  }

  describe("Deployment", function () {
    it("Should deploy the contract", async function () {
      const { myNft, owner } = await loadFixture(deployMyNftFixture);

      expect(await myNft.name()).to.equal("MyOnChainNft");
      expect(await myNft.symbol()).to.equal("MONFT");
      expect(await myNft.owner()).to.equal(owner.address);
    });
  });

  describe("Minting", function () {
    it("Should mint an NFT with simple metadata", async function () {
      const { myNft, owner } = await loadFixture(deployMyNftFixture);
      const tokenId = await myNft.getNextTokenId();
      expect(tokenId).to.equal(0);
      
      const name = "Test Token";
      const description = "A test NFT";
      const image = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyMDAiIGhlaWdodD0iMjAwIj48cmVjdCB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgZmlsbD0iYmx1ZSIvPjx0ZXh0IHg9IjEwMCIgeT0iMTAwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSJ3aGl0ZSI+VGVzdDwvdGV4dD48L3N2Zz4=";
      
      const tx = await myNft.mintSimple(owner.address, name, description, image);
      await expect(tx)
        .to.emit(myNft, "NftMinted")
        .withArgs(0, owner.address, name);
      
      expect(await myNft.ownerOf(tokenId)).to.equal(owner.address);
      expect(await myNft.getNextTokenId()).to.equal(1);
      
      // Check metadata
      const [metadataName, metadataDesc, metadataImage, metadataAttrs, metadataVals] = await myNft.getTokenMetadata(tokenId);
      expect(metadataName).to.equal(name);
      expect(metadataDesc).to.equal(description);
      expect(metadataImage).to.equal(image);
      expect(metadataAttrs.length).to.equal(0);
      expect(metadataVals.length).to.equal(0);
    });

    it("Should mint an NFT with full metadata", async function () {
      const { myNft, owner } = await loadFixture(deployMyNftFixture);
      const tokenId = await myNft.getNextTokenId();
      
      const name = "Full Token";
      const description = "A full featured NFT";
      const image = "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTAwIiBoZWlnaHQ9IjEwMCI+PC9zdmc+";
      const attributes = ["Color", "Rarity"];
      const values = ["Blue", "Rare"];
      
      const tx = await myNft.mint(owner.address, name, description, image, attributes, values);
      await expect(tx)
        .to.emit(myNft, "NftMinted")
        .withArgs(0, owner.address, name);
      
      expect(await myNft.ownerOf(tokenId)).to.equal(owner.address);
      
      // Check metadata - debug the array lengths first
      const [metadataName, metadataDesc, metadataImage, metadataAttrs, metadataVals] = await myNft.getTokenMetadata(tokenId);
      expect(metadataName).to.equal(name);
      expect(metadataDesc).to.equal(description);
      expect(metadataImage).to.equal(image);
      
      expect(metadataAttrs.length).to.equal(attributes.length);
      expect(metadataVals.length).to.equal(values.length);
      if (attributes.length > 0) {
        expect(metadataAttrs[0]).to.equal("Color");
        expect(metadataAttrs[1]).to.equal("Rarity");
        expect(metadataVals[0]).to.equal("Blue");
        expect(metadataVals[1]).to.equal("Rare");
      }
    });

    it("Should allow another account to mint an NFT", async function () {
      const { myNft, owner, otherAccount } = await loadFixture(
        deployMyNftFixture
      );
      expect(await myNft.getNextTokenId()).to.equal(0);
      
      const name1 = "Token 1";
      const name2 = "Token 2";
      const description = "Test NFT";
      const image = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyMDAiIGhlaWdodD0iMjAwIj48cmVjdCB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgZmlsbD0iZ3JlZW4iLz48dGV4dCB4PSIxMDAiIHk9IjEwMCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZmlsbD0id2hpdGUiPlRlc3Q8L3RleHQ+PC9zdmc+";

      // Mint first NFT to owner
      await myNft.mintSimple(owner.address, name1, description, image);
      expect(await myNft.getNextTokenId()).to.equal(1);

      // Mint second NFT to otherAccount
      const tx = await myNft.mintSimple(otherAccount.address, name2, description, image);
      await expect(tx)
        .to.emit(myNft, "NftMinted")
        .withArgs(1, otherAccount.address, name2);

      // Check the second NFT (token ID 1)
      expect(await myNft.ownerOf(1)).to.equal(otherAccount.address);
      expect(await myNft.getNextTokenId()).to.equal(2);
      
      const [metadataName, metadataDesc, metadataImage, metadataAttrs, metadataVals] = await myNft.getTokenMetadata(1);
      expect(metadataName).to.equal(name2);
    });

    it("Should return valid tokenURI with base64 encoded JSON", async function () {
      const { myNft, owner } = await loadFixture(deployMyNftFixture);
      
      const name = "URI Test Token";
      const description = "Testing tokenURI";
      const image = "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTAwIiBoZWlnaHQ9IjEwMCI+PC9zdmc+";
      const attributes = ["Color"];
      const values = ["Red"];
      
      await myNft.mint(owner.address, name, description, image, attributes, values);
      
      const tokenURI = await myNft.tokenURI(0);
      expect(tokenURI).to.include("data:application/json;base64,");
      
      // Decode and verify JSON structure
      const base64Data = tokenURI.replace("data:application/json;base64,", "");
      const jsonString = Buffer.from(base64Data, 'base64').toString('utf8');
      const metadata = JSON.parse(jsonString);
      
      expect(metadata.name).to.equal(name);
      expect(metadata.description).to.equal(description);
      expect(metadata.image).to.equal(image);
      expect(metadata.tokenId).to.equal(0);
      expect(metadata.attributes).to.have.lengthOf(1);
      expect(metadata.attributes[0].trait_type).to.equal("Color");
      expect(metadata.attributes[0].value).to.equal("Red");
    });

    it("Should revert if the name is empty", async function () {
      const { myNft, owner } = await loadFixture(deployMyNftFixture);
      const name = "";
      const description = "Test";
      const image = "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTAwIiBoZWlnaHQ9IjEwMCI+PC9zdmc+";
      
      await expect(
        myNft.mintSimple(owner.address, name, description, image)
      ).to.be.revertedWithCustomError(myNft, "MyOnChainNft_NoName");
    });

    it("Should revert if the recipient is the zero address", async function () {
      const { myNft } = await loadFixture(deployMyNftFixture);
      const name = "Test Token";
      const description = "Test";
      const image = "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTAwIiBoZWlnaHQ9IjEwMCI+PC9zdmc+";
      
      await expect(
        myNft.mintSimple(hre.ethers.ZeroAddress, name, description, image)
      ).to.be.revertedWithCustomError(myNft, "MyOnChainNft_NoRecipient");
    });

    it("Should revert if attributes and values arrays length mismatch", async function () {
      const { myNft, owner } = await loadFixture(deployMyNftFixture);
      const name = "Test Token";
      const description = "Test";
      const image = "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTAwIiBoZWlnaHQ9IjEwMCI+PC9zdmc+";
      const attributes = ["Color", "Rarity"];
      const values = ["Blue"]; // Mismatch: 2 attributes, 1 value
      
      await expect(
        myNft.mint(owner.address, name, description, image, attributes, values)
      ).to.be.revertedWithCustomError(myNft, "MyOnChainNft_AttributesMismatch");
    });

    it("Should only allow owner to mint", async function () {
      const { myNft, owner, otherAccount } = await loadFixture(deployMyNftFixture);
      const name = "Test Token";
      const description = "Test";
      const image = "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTAwIiBoZWlnaHQ9IjEwMCI+PC9zdmc+";
      
      await expect(
        myNft.connect(otherAccount).mintSimple(otherAccount.address, name, description, image)
      ).to.be.revertedWithCustomError(myNft, "OwnableUnauthorizedAccount");
    });
  });

  describe("Metadata Management", function () {
    it("Should update token metadata", async function () {
      const { myNft, owner } = await loadFixture(deployMyNftFixture);
      
      // Mint initial token
      await myNft.mintSimple(owner.address, "Original", "Original desc", "original_image");
      
      // Update metadata
      const newName = "Updated Token";
      const newDescription = "Updated description";
      const newImage = "updated_image";
      const newAttributes = ["Updated"];
      const newValues = ["Value"];
      
      await myNft.updateTokenMetadata(0, newName, newDescription, newImage, newAttributes, newValues);
      
      const [metadataName, metadataDesc, metadataImage, metadataAttrs, metadataVals] = await myNft.getTokenMetadata(0);
      expect(metadataName).to.equal(newName);
      expect(metadataDesc).to.equal(newDescription);
      expect(metadataImage).to.equal(newImage);
      expect(metadataAttrs.length).to.equal(1);
      expect(metadataVals.length).to.equal(1);
      if (metadataAttrs.length > 0) {
        expect(metadataAttrs[0]).to.equal("Updated");
        expect(metadataVals[0]).to.equal("Value");
      }
    });

    it("Should revert when updating non-existent token", async function () {
      const { myNft, owner } = await loadFixture(deployMyNftFixture);
      
      await expect(
        myNft.updateTokenMetadata(999, "Name", "Desc", "Image", [], [])
      ).to.be.revertedWithCustomError(myNft, "MyOnChainNft_NotMinted");
    });

    it("Should only allow owner to update metadata", async function () {
      const { myNft, owner, otherAccount } = await loadFixture(deployMyNftFixture);
      
      await myNft.mintSimple(owner.address, "Test", "Test", "test_image");
      
      await expect(
        myNft.connect(otherAccount).updateTokenMetadata(0, "Hacked", "Hacked", "hacked", [], [])
      ).to.be.revertedWithCustomError(myNft, "OwnableUnauthorizedAccount");
    });
  });

  describe("Burning", function () {
    it("Should burn an NFT and delete metadata", async function () {
      const { myNft, owner } = await loadFixture(deployMyNftFixture);
      const tokenId = await myNft.getNextTokenId();
      
      await myNft.mintSimple(owner.address, "Burn Test", "To be burned", "burn_image");
      expect(await myNft.ownerOf(tokenId)).to.equal(owner.address);
      expect(await myNft.balanceOf(owner.address)).to.equal(1);

      const burnTx = await myNft.burn(tokenId);
      await expect(burnTx).to.emit(myNft, "NftBurned").withArgs(tokenId);
      expect(await myNft.balanceOf(owner.address)).to.equal(0);
      
      // Should revert when trying to get metadata of burned token
      await expect(
        myNft.getTokenMetadata(tokenId)
      ).to.be.revertedWithCustomError(myNft, "MyOnChainNft_NotMinted");
      
      // Should revert when trying to get tokenURI of burned token
      await expect(
        myNft.tokenURI(tokenId)
      ).to.be.revertedWithCustomError(myNft, "MyOnChainNft_NotMinted");
    });

    it("Should only allow owner to burn", async function () {
      const { myNft, owner, otherAccount } = await loadFixture(deployMyNftFixture);
      
      await myNft.mintSimple(owner.address, "Test", "Test", "test_image");
      
      await expect(
        myNft.connect(otherAccount).burn(0)
      ).to.be.revertedWithCustomError(myNft, "OwnableUnauthorizedAccount");
    });
  });

  describe("SVG Generation", function () {
    it("Should generate SVG correctly", async function () {
      const { myNft } = await loadFixture(deployMyNftFixture);
      
      const svg = await myNft.generateSVG(1, "blue");
      expect(svg).to.include('<svg xmlns="http://www.w3.org/2000/svg"');
      expect(svg).to.include('fill="blue"');
      expect(svg).to.include('Token #1');
      expect(svg).to.include('width="200" height="200"');
    });

    it("Should generate SVG data URI correctly", async function () {
      const { myNft } = await loadFixture(deployMyNftFixture);
      
      const dataURI = await myNft.generateSVGDataURI(5, "red");
      expect(dataURI).to.include("data:image/svg+xml;base64,");
      
      // Decode and verify the SVG content
      const base64Data = dataURI.replace("data:image/svg+xml;base64,", "");
      const svgContent = Buffer.from(base64Data, 'base64').toString('utf8');
      expect(svgContent).to.include('fill="red"');
      expect(svgContent).to.include('Token #5');
    });

    it("Should mint with generated image", async function () {
      const { myNft, owner } = await loadFixture(deployMyNftFixture);
      
      const name = "Generated Token";
      const description = "Token with generated SVG";
      const color = "green";
      const attributes = ["Color", "Type"];
      const values = ["Green", "Generated"];
      
      const tx = await myNft.mintWithGeneratedImage(
        owner.address, 
        name, 
        description, 
        color, 
        attributes, 
        values
      );
      
      await expect(tx)
        .to.emit(myNft, "NftMinted")
        .withArgs(0, owner.address, name);
      
      // Verify the token was minted
      expect(await myNft.ownerOf(0)).to.equal(owner.address);
      
      // Check metadata
      const [metadataName, metadataDesc, metadataImage, metadataAttrs, metadataVals] = await myNft.getTokenMetadata(0);
      expect(metadataName).to.equal(name);
      expect(metadataDesc).to.equal(description);
      expect(metadataImage).to.include("data:image/svg+xml;base64,");
      
      expect(metadataAttrs.length).to.equal(2);
      expect(metadataVals.length).to.equal(2);
      
      // Verify the generated image content
      const base64Data = metadataImage.replace("data:image/svg+xml;base64,", "");
      const svgContent = Buffer.from(base64Data, 'base64').toString('utf8');
      expect(svgContent).to.include('fill="green"');
      expect(svgContent).to.include('Token #0');
    });

    it("Should generate different SVGs for different tokens", async function () {
      const { myNft, owner } = await loadFixture(deployMyNftFixture);
      
      // Mint two tokens with different colors
      await myNft.mintWithGeneratedImage(owner.address, "Token 1", "First", "blue", [], []);
      await myNft.mintWithGeneratedImage(owner.address, "Token 2", "Second", "red", [], []);
      
      const [name1, desc1, image1, attrs1, vals1] = await myNft.getTokenMetadata(0);
      const [name2, desc2, image2, attrs2, vals2] = await myNft.getTokenMetadata(1);
      
      // Images should be different
      expect(image1).to.not.equal(image2);
      
      // Decode and verify different content
      const svg1 = Buffer.from(
        image1.replace("data:image/svg+xml;base64,", ""), 
        'base64'
      ).toString('utf8');
      const svg2 = Buffer.from(
        image2.replace("data:image/svg+xml;base64,", ""), 
        'base64'
      ).toString('utf8');
      
      expect(svg1).to.include('fill="blue"');
      expect(svg1).to.include('Token #0');
      expect(svg2).to.include('fill="red"');
      expect(svg2).to.include('Token #1');
    });

    it("Should only allow owner to mint with generated image", async function () {
      const { myNft, owner, otherAccount } = await loadFixture(deployMyNftFixture);
      
      await expect(
        myNft.connect(otherAccount).mintWithGeneratedImage(
          otherAccount.address,
          "Unauthorized",
          "Should fail",
          "purple",
          [],
          []
        )
      ).to.be.revertedWithCustomError(myNft, "OwnableUnauthorizedAccount");
    });
  });
});