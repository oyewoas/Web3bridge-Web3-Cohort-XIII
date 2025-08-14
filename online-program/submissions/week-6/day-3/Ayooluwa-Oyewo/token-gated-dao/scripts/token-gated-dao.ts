import { network } from "hardhat";

const { ethers } = await network.connect({
  network: "hardhatOp",
  chainType: "op",
});

async function main() {
    console.log("Deploying Token-Gated DAO with ERC-7432...");
    
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with account:", deployer.address);
    const balance = deployer.provider ? await deployer.provider.getBalance(deployer.address) : 0;
    console.log("Account balance:", balance.toString());
    
    // Deploy RoleNFT
    const RoleNFT = await ethers.getContractFactory("RoleNFT");
    const roleNFT = await RoleNFT.deploy("DAO Membership NFT", "DAONFT");
    await roleNFT.waitForDeployment();
    console.log("RoleNFT deployed to:", await roleNFT.getAddress());
    
    // Deploy TokenGatedDAO
    const TokenGatedDAO = await ethers.getContractFactory("TokenGatedDAO");
    const dao = await TokenGatedDAO.deploy(await roleNFT.getAddress());
    await dao.waitForDeployment();
    console.log("TokenGatedDAO deployed to:", await dao.getAddress());
    
    // Setup initial NFTs and roles for demo
    console.log("\nSetting up demo data...");
    
    const [owner, user1, user2, user3] = await ethers.getSigners();
    
    // Mint NFTs
    const tx1 = await roleNFT.mint(user1.address);
    await tx1.wait();
    const tokenId1 = 1;
    
    const tx2 = await roleNFT.mint(user2.address);
    await tx2.wait();
    const tokenId2 = 2;
    
    const tx3 = await roleNFT.mint(user3.address);
    await tx3.wait();
    const tokenId3 = 3;
    
    console.log(`Minted NFT #${tokenId1} to ${user1.address}`);
    console.log(`Minted NFT #${tokenId2} to ${user2.address}`);
    console.log(`Minted NFT #${tokenId3} to ${user3.address}`);
    
    // Grant roles
    const VOTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("VOTER"));
    const PROPOSER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("PROPOSER"));
    const ADMIN_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ADMIN"));
    
    // Grant VOTER and PROPOSER roles to user1 (expires in 1 year)
    const oneYearFromNow = Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60);
    await roleNFT.connect(user1).grantRole(tokenId1, VOTER_ROLE, user1.address, oneYearFromNow, true, "0x");
    await roleNFT.connect(user1).grantRole(tokenId1, PROPOSER_ROLE, user1.address, oneYearFromNow, true, "0x");

    // Grant VOTER role to user2
    await roleNFT.connect(user2).grantRole(tokenId2, VOTER_ROLE, user2.address, oneYearFromNow, true, "0x");

    // Grant ADMIN role to user3 (permanent - no expiration)
    await roleNFT.connect(user3).grantRole(tokenId3, ADMIN_ROLE, user3.address, 0, false, "0x");
    await roleNFT.connect(user3).grantRole(tokenId3, VOTER_ROLE, user3.address, 0, false, "0x");
    await roleNFT.connect(user3).grantRole(tokenId3, PROPOSER_ROLE, user3.address, 0, false, "0x");

    console.log("Granted VOTER and PROPOSER roles to user1");
    console.log("Granted VOTER role to user2");
    console.log("Granted ADMIN, VOTER, and PROPOSER roles to user3");
    
    // Send some ETH to the DAO for demonstration
    await owner.sendTransaction({
        to: await dao.getAddress(),
        value: ethers.parseEther("1.0")
    });
    console.log("Sent 1 ETH to DAO treasury");
    
    console.log("\nDeployment completed!");
    console.log("================================");
    console.log("RoleNFT address:", await roleNFT.getAddress());
    console.log("TokenGatedDAO address:", await dao.getAddress());
    console.log("================================");

  // ==========================
// INTERACTING WITH THE DAO
// ==========================

// 1. User1 (who owns NFT #1 and has PROPOSER_ROLE) submits a proposal
console.log("\n--- DAO Interaction Demo ---");
const proposalDescription = "Fund community event with 0.2 ETH";
const targetContract = user2.address; // Example: sending ETH directly to a member
const callData = "0x"; // No function call, just ETH transfer

const proposeTx = await dao.connect(user1).propose(
    "Community Event Funding", // title
    proposalDescription,       // description
    targetContract,            // target
    callData,                  // callData
    ethers.parseEther("0.2"),  // value
    {}                         // overrides (empty object)
);
const proposeReceipt = await proposeTx.wait();
if (proposeReceipt) {
    console.log(`Proposal created by ${user1.address}:`, proposeReceipt.hash);
} else {
    console.log(`Proposal created by ${user1.address}, but receipt is null.`);
}

// Assume the DAO increments proposal IDs starting from 1
const proposalId = 1;

// 2. Fast forward time to start voting (for demo purposes)
await ethers.provider.send("evm_increaseTime", [60]); // +1 minute
await ethers.provider.send("evm_mine");

// 3. User1 votes "yes"
await dao.connect(user1).vote(proposalId, true);
console.log(`${user1.address} voted YES`);

// 4. User2 votes "no"
await dao.connect(user2).vote(proposalId, false);
console.log(`${user2.address} voted NO`);

// 5. Fast forward time to end voting
await ethers.provider.send("evm_increaseTime", [7 * 24 * 60 * 60]); // +7 days
await ethers.provider.send("evm_mine");

// 6. Execute proposal (if passed)
try {
    await dao.connect(user3).execute(proposalId);
    console.log(`Proposal ${proposalId} executed successfully`);
} catch (err) {
    if (err instanceof Error) {
        console.log(`Proposal ${proposalId} failed execution:`, err.message);
    } else {
        console.log(`Proposal ${proposalId} failed execution:`, err);
    }
}
    console.log("================================");
    console.log("Demo completed!");
    console.log("================================");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
