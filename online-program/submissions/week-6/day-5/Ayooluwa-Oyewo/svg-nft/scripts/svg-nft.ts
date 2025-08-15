import { network } from "hardhat";

const { ethers } = await network.connect({
  network: "hardhatOp",
  chainType: "op",
});

console.log("Deploying SVG NFT contract on OP chain");

const [deployer] = await ethers.getSigners();
console.log("Deploying from address:", deployer.address);

// Get the contract factory
const SvgNft = await ethers.getContractFactory("SvgNft");

// Deploy the contract
console.log("Deploying SvgNft contract...");
const svgNft = await SvgNft.deploy();
await svgNft.waitForDeployment();

const contractAddress = await svgNft.getAddress();
console.log("SvgNft deployed to:", contractAddress);

// Mint a simple NFT to test
console.log("Minting a test NFT...");
const mintTx = await svgNft.mintSimple(
  deployer.address,
  "Dynamic Time Clock #1",
  "A beautiful NFT that shows the current blockchain time"
);

await mintTx.wait();
console.log("NFT minted successfully");

// Get the token ID (should be 0 for first mint)
const nextTokenId = await svgNft.getNextTokenId();
const currentTokenId = nextTokenId - 1n;

console.log("Token ID:", currentTokenId.toString());

// Get current time from the contract
const [timeString, dateString, timestamp] = await svgNft.getCurrentTime();
console.log("Current blockchain time:", timeString);
console.log("Current blockchain date:", dateString);
console.log("Block timestamp:", timestamp.toString());

// Get the token URI (this will show the dynamic SVG)
console.log("Getting token URI with dynamic SVG...");
const tokenURI = await svgNft.tokenURI(currentTokenId);
console.log("Token URI:", tokenURI);

// Mint a custom NFT with specific colors and attributes
console.log("Minting a custom NFT...");
const customMintTx = await svgNft.mint(
  deployer.address,
  "Sunset Timer",
  "A warm-themed time display NFT",
  "#ff6b6b", // Red background
  "#ffffff", // White text
  ["Theme", "Style", "Creator"], // Attributes
  ["Sunset", "Digital Clock", "Test Script"] // Values
);

await customMintTx.wait();
console.log("Custom NFT minted successfully");

const customTokenId = nextTokenId;
console.log("Custom Token ID:", customTokenId.toString());

// Get metadata for the custom token
const [name, description, bgColor, textColor, attributes, values] = await svgNft.getTokenMetadata(customTokenId);
console.log("Custom NFT Metadata:");
console.log("Name:", name);
console.log("Description:", description);
console.log("Background Color:", bgColor);
console.log("Text Color:", textColor);
console.log("Attributes:", attributes);
console.log("Values:", values);

console.log("Script completed successfully!");
console.log("Contract deployed at:", contractAddress);
console.log("Total tokens minted:", (await svgNft.getNextTokenId()).toString());

// Get the SVG for the custom token
const customTokenSVG = await svgNft.generateTimeSVG(customTokenId);
console.log("Custom Token SVG:", customTokenSVG);

// Get token URI
const customTokenURI = await svgNft.tokenURI(customTokenId);
console.log("Custom Token URI:", customTokenURI);