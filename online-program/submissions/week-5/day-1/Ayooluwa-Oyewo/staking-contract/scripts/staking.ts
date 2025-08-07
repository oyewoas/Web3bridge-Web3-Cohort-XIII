import hre from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";

async function main() {
  const [owner, otherAccount] = await hre.ethers.getSigners();

  console.log("Deploying Staking contract...");
  console.log("Owner address:", owner.address);

  // Deploy the Staking contract
  const TokenA = await hre.ethers.getContractFactory("TokenA");
  const initialSupplyA = hre.ethers.parseEther("1000000"); // 1 million tokens
  const tokenA = await TokenA.deploy(initialSupplyA);
  await tokenA.waitForDeployment();

  console.log("TokenA deployed to:", tokenA.target);
  console.log("TokenA deployed at timestamp:", new Date().toISOString());

  const TokenB = await hre.ethers.getContractFactory("TokenB");
  const tokenB = await TokenB.deploy();
  await tokenB.waitForDeployment();
  console.log("TokenB deployed to:", tokenB.target);
  console.log("TokenB deployed at timestamp:", new Date().toISOString());

  const Staking = await hre.ethers.getContractFactory("Staking");
  const lockupPeriod = 30 * 24 * 60 * 60; // 30 days in seconds
  const staking = await Staking.deploy(
    tokenA.target,
    tokenB.target,
    lockupPeriod
  );
  await staking.waitForDeployment();
  console.log("Set staking contract as minter for TokenB");
  await tokenB.setMinter(staking.target, true);
  console.log("Staking contract deployed to:", staking.target);
  console.log(
    "Staking contract deployed at timestamp:",
    new Date().toISOString()
  );

  // Verify deployment on network (uncomment for testnets/mainnet)
  if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
    console.log("Waiting for block confirmations...");
    await staking.deploymentTransaction()?.wait(6);

    try {
      await hre.run("verify:verify", {
        address: staking.target,
        constructorArguments: [tokenA.target, tokenB.target, lockupPeriod],
      });
      console.log("Contract verified on Etherscan");
    } catch (error) {
      if (error instanceof Error) {
        console.log("Verification failed:", error.message);
      } else {
        console.log("Verification failed:", error);
      }
    }
  }

  // Test contract functionality
  console.log("\n--- Testing Contract Functionality ---");

  // Stake tokens
  const amountToStake = hre.ethers.parseEther("10"); // 10 tokens
  console.log(`Staking ${hre.ethers.formatEther(amountToStake)} TokenA...`);
  // Approve the staking contract to spend TokenA
  const approveTx = await tokenA.approve(staking.target, amountToStake);
  await approveTx.wait();
  console.log("Approval transaction confirmed:", approveTx.hash);
  const stakeTx = await staking.stake(amountToStake);
  await stakeTx.wait();

  // Give other account some TokenA to stake
  const otherAmountToStake = hre.ethers.parseEther("5"); // 5 tokens
  await tokenA.transfer(otherAccount.address, otherAmountToStake);

  // Give allow other account to stake
  const approveTxOther = await tokenA
    .connect(otherAccount)
    .approve(staking.target, otherAmountToStake);
  await approveTxOther.wait();
  console.log(
    "Approval transaction confirmed for other account:",
    approveTxOther.hash
  );

  console.log(
    `Transferred ${hre.ethers.formatEther(
      otherAmountToStake
    )} TokenA to other account:`,
    otherAccount.address
  );

  const stakeTxOther = await staking
    .connect(otherAccount)
    .stake(otherAmountToStake);
  await stakeTxOther.wait();

  console.log("Stake transaction confirmed for owner:", stakeTx.hash);
  console.log(
    "Stake transaction confirmed for other account:",
    stakeTxOther.hash
  );
  console.log("Stake successful!");

  try {
    // Check staking balance
    const stakingInfo = await staking.getStakeInfo(owner.address);
    const stakingInfoOther = await staking.getStakeInfo(otherAccount.address);

    console.log(
      `Staking balance of ${owner.address}:`,
      stakingInfo.amount.toString()
    );
    console.log(
      `Staking balance of ${otherAccount.address}:`,
      stakingInfoOther.amount.toString()
    );
  } catch (error) {
    if (error instanceof Error) {
      console.log("Error fetching student details:", error.message);
    } else {
      console.log("Error fetching student details:", error);
    }
  }

  // Unstake tokens
  console.log(`Unstaking ${hre.ethers.formatEther(amountToStake)} TokenA...`);
  await time.increase(30 * 24 * 60 * 60); // Fast forward time by 30 days to meet lockup period
  console.log("Fast forwarded time by 30 days for lockup period.");
  const unstakeTx = await staking.unstake(amountToStake);
  await unstakeTx.wait();
  const unstakeTxOther = await staking
    .connect(otherAccount)
    .unstake(otherAmountToStake);
  await unstakeTxOther.wait();
  console.log("Unstake transaction confirmed for owner:", unstakeTx.hash);
  console.log(
    "Unstake transaction confirmed for other account:",
    unstakeTxOther.hash
  );
  // Get staking balance after unstaking
  try {
    const stakingInfo = await staking.getStakeInfo(owner.address);
    const stakingInfoOther = await staking.getStakeInfo(otherAccount.address);
    console.log(
      `Staking balance of ${owner.address}:`,
      stakingInfo.amount.toString()
    );
    console.log(
      `Staking balance of other ${otherAccount.address}:`,
      stakingInfoOther.amount.toString()
    );
  } catch (error) {
    if (error instanceof Error) {
      console.log("Error fetching staking balance:", error.message);
    } else {
      console.log("Error fetching staking balance:", error);
    }
  }
  console.log("Unstake transaction confirmed for owner:", unstakeTx.hash);
  console.log(
    "Unstake transaction confirmed for other account:",
    unstakeTxOther.hash
  );
  console.log("Unstake successful!");

  // Save deployment info
  const deploymentInfo = {
    contractAddress: staking.target,
    network: hre.network.name,
    deployer: owner.address,
    blockNumber: await hre.ethers.provider.getBlockNumber(),
    timestamp: new Date().toISOString(),
  };

  console.log("\n--- Deployment Summary ---");
  console.log(JSON.stringify(deploymentInfo, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });
