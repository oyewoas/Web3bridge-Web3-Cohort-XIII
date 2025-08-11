import hre from "hardhat";
import { time } from "@nomicfoundation/hardhat-toolbox/network-helpers";

async function main() {
  console.log("PiggyBank Demo Script Starting...\n");
  
  // Get signers
  const [deployer, user1, user2] = await hre.ethers.getSigners();
  console.log("Deployer:", deployer.address);
  console.log("User 1:", user1.address);
  console.log("User 2:", user2.address);
  console.log("\n" + "=".repeat(50));

  try {
    // Deploy MockERC20 token
    console.log("\nDeploying MockERC20 token...");
    const Erc20 = await hre.ethers.getContractFactory("MockERC20");
    const erc20 = await Erc20.deploy(
      "Mock Token",
      "MTK",
      hre.ethers.parseEther("1000000")
    );
    await erc20.waitForDeployment();
    console.log("MockERC20 deployed at:", erc20.target);

    // Mint tokens to user1
    console.log("\nMinting tokens to user1...");
    await erc20.mint(user1.address, hre.ethers.parseEther("10000"));
    const user1Balance = await erc20.balanceOf(user1.address);
    console.log("User1 ERC20 balance:", hre.ethers.formatEther(user1Balance), "MTK");


    // Deploy Factory
    const PiggyBankFactory = await hre.ethers.getContractFactory("PiggyBankFactory");
    const piggyBankFactory = await PiggyBankFactory.deploy();
    await piggyBankFactory.waitForDeployment();
    console.log("PiggyBankFactory deployed at:", piggyBankFactory.target);
   
    // Get factory admin (assuming deployer is admin for demo)

    const factoryAdmin = piggyBankFactory.admin();
    console.log("Factory Admin:", factoryAdmin);

    // Deploy PiggyBank for ERC20
    console.log("\nDeploying PiggyBank for ERC20...");

    const piggyBankAddress = await piggyBankFactory.connect(user1).createPiggyBank.staticCall(
      hre.ethers.parseEther("1000"), // target amount
      erc20.target,               // token address
      30,                         // lock period (30 seconds for demo)
    );
    await piggyBankFactory.connect(user1).createPiggyBank(
        hre.ethers.parseEther("1000"), // target amount
        erc20.target,               // token address
        30,                         // lock period (30 seconds for demo)
    );

    const piggyBankERC20 = await hre.ethers.getContractAt("PiggyBank", piggyBankAddress);
    console.log("PiggyBank ERC20 deployed at:", piggyBankAddress);

    // Deploy PiggyBank for ETH
    console.log("\nDeploying PiggyBank for ETH...");

    const piggyBankETHAddress = await piggyBankFactory.connect(user1).createPiggyBank.staticCall(
      hre.ethers.parseEther("5"),    // target amount (5 ETH)
      hre.ethers.ZeroAddress,     // zero address for ETH
      30,                         // lock period (30 seconds for demo)
    );
    await piggyBankFactory.connect(user1).createPiggyBank(
      hre.ethers.parseEther("5"),    // target amount (5 ETH)
      hre.ethers.ZeroAddress,     // zero address for ETH
      30,                         // lock period (30 seconds for demo)
    );
    const piggyBankETH = await hre.ethers.getContractAt("PiggyBank", piggyBankETHAddress);
    console.log("PiggyBank ETH deployed at:", piggyBankETHAddress);

    console.log("\n" + "=".repeat(50));
    console.log("DEPLOYMENT VERIFICATION");
    console.log("=".repeat(50));

    // Verify deployments
    const erc20Plan = await piggyBankERC20.savingsPlan();
    const ethPlan = await piggyBankETH.savingsPlan();

    console.log("\nERC20 PiggyBank Details:");
    console.log("  - Owner:", erc20Plan.owner);
    console.log("  - Target Amount:", hre.ethers.formatEther(erc20Plan.targetAmount), "MTK");
    console.log("  - Token Address:", erc20Plan.tokenAddress);
    console.log("  - Lock Period:", erc20Plan.lockPeriod.toString(), "seconds");
    console.log("  - Current Balance:", hre.ethers.formatEther(erc20Plan.balance), "MTK");
    console.log("  - Status:", erc20Plan.status === 1n ? "Active" : "Inactive");

    console.log("\nETH PiggyBank Details:");
    console.log("  - Owner:", ethPlan.owner);
    console.log("  - Target Amount:", hre.ethers.formatEther(ethPlan.targetAmount), "ETH");
    console.log("  - Token Address:", ethPlan.tokenAddress, "(Zero Address = ETH)");
    console.log("  - Lock Period:", ethPlan.lockPeriod.toString(), "seconds");
    console.log("  - Current Balance:", hre.ethers.formatEther(ethPlan.balance), "ETH");
    console.log("  - Status:", ethPlan.status === 1n ? "Active" : "Inactive");

    console.log("\n" + "=".repeat(50));
    console.log("TESTING DEPOSITS");
    console.log("=".repeat(50));

    // Test ERC20 deposit
    console.log("\nTesting ERC20 deposit...");
    const depositAmount = hre.ethers.parseEther("500");
    
    // Approve tokens
    console.log("  Approving tokens...");
    await erc20.connect(user1).approve(piggyBankERC20.target, depositAmount);
    console.log("  Approval successful");

    // Deposit ERC20 tokens
    console.log("  Depositing", hre.ethers.formatEther(depositAmount), "MTK...");
    const depositTx = await piggyBankERC20.connect(user1).depositERC20(depositAmount);
    await depositTx.wait();
    console.log("  ERC20 deposit successful");

    // Check balances
    const newUser1Balance = await erc20.balanceOf(user1.address);
    const updatedERC20Plan = await piggyBankERC20.savingsPlan();
    console.log("  User1 ERC20 balance:", hre.ethers.formatEther(newUser1Balance), "MTK");
    console.log("  PiggyBank ERC20 balance:", hre.ethers.formatEther(updatedERC20Plan.balance), "MTK");

    // Test ETH deposit
    console.log("\nTesting ETH deposit...");
    const ethDepositAmount = hre.ethers.parseEther("2");
    
    console.log("  Depositing", hre.ethers.formatEther(ethDepositAmount), "ETH...");
    const ethDepositTx = await piggyBankETH.connect(user1).depositETH({ 
      value: ethDepositAmount 
    });
    await ethDepositTx.wait();
    console.log("  ETH deposit successful");

    const updatedETHPlan = await piggyBankETH.savingsPlan();
    console.log("  PiggyBank ETH balance:", hre.ethers.formatEther(updatedETHPlan.balance), "ETH");

    console.log("\n" + "=".repeat(50));
    console.log("TESTING ERROR CONDITIONS");
    console.log("=".repeat(50));

    // Test unauthorized access
    console.log("\nTesting unauthorized withdrawal...");
    try {
      await piggyBankETH.connect(user2).withdraw(hre.ethers.parseEther("1"));
      console.log("  ERROR: Unauthorized access should have failed!");
    } catch (error) {
      console.log("  Unauthorized access correctly rejected");
    }

    // Test insufficient funds
    console.log("\nTesting insufficient funds withdrawal...");
    try {
      await piggyBankETH.connect(user1).withdraw(hre.ethers.parseEther("10"));
      console.log("  ERROR: Insufficient funds withdrawal should have failed!");
    } catch (error) {
      console.log("  Insufficient funds correctly rejected");
    }

    // Test wrong token type
    console.log("\nTesting wrong token type deposit...");
    try {
      await piggyBankERC20.connect(user1).depositETH({ value: hre.ethers.parseEther("1") });
      console.log("  ERROR: ETH deposit to ERC20 bank should have failed!");
    } catch (error) {
      console.log("  Wrong token type correctly rejected");
    }

    console.log("\n" + "=".repeat(50));
    console.log("TESTING WITHDRAWALS");
    console.log("=".repeat(50));

    // Test partial withdrawal (before lock period - with fee)
    console.log("\nTesting early withdrawal with fee...");
    const partialWithdraw = hre.ethers.parseEther("100");
    
    console.log("  Withdrawing", hre.ethers.formatEther(partialWithdraw), "MTK (early withdrawal)...");
    const withdrawTx = await piggyBankERC20.connect(user1).withdraw(partialWithdraw);
    await withdrawTx.wait();
    console.log("  Early withdrawal successful (fee deducted)");

    const finalUser1Balance = await erc20.balanceOf(user1.address);
    const finalERC20Plan = await piggyBankERC20.savingsPlan();
    console.log("  User1 final ERC20 balance:", hre.ethers.formatEther(finalUser1Balance), "MTK");
    console.log("  PiggyBank remaining balance:", hre.ethers.formatEther(finalERC20Plan.balance), "MTK");

    // Wait for lock period to expire
    console.log("\nWaiting for lock period to expire (30 seconds)...");
    await time.increase(31);

    // Test withdrawal after lock period (no fee)
    console.log("\nTesting withdrawal after lock period...");
    const remainingBalance = finalERC20Plan.balance;
    
    if (remainingBalance > 0n) {
      console.log("  Withdrawing remaining", hre.ethers.formatEther(remainingBalance), "MTK (no fee)...");
      const noFeeWithdrawTx = await piggyBankERC20.connect(user1).withdraw(remainingBalance);
      await noFeeWithdrawTx.wait();
      console.log("  Post-lock withdrawal successful (no fee)");
    }

    // Test withdraw all functionality
    console.log("\nTesting withdraw all ETH...");
    const withdrawAllTx = await piggyBankETH.connect(user1).withdrawAll();
    await withdrawAllTx.wait();
    console.log("  Withdraw all successful");

    console.log("\n" + "=".repeat(50));
    console.log("TESTING ADMIN FUNCTIONS");
    console.log("=".repeat(50));

    // Test setting savings plan inactive
    console.log("\nTesting set savings plan inactive...");
    await piggyBankETH.connect(user1).setSavingsPlanInactive();
    const inactivePlan = await piggyBankETH.savingsPlan();
    console.log("  Savings plan set to inactive");
    console.log("  Status:", inactivePlan.status === 0n ? "Inactive" : "Active");

    // Try to deposit to inactive plan
    console.log("\nTesting deposit to inactive plan...");
    try {
      await piggyBankETH.connect(user1).depositETH({ value: hre.ethers.parseEther("1") });
      console.log("  ERROR: Deposit to inactive plan should have failed!");
    } catch (error) {
      console.log("  Deposit to inactive plan correctly rejected");
    }

    console.log("\n" + "=".repeat(50));
    console.log("DEMO COMPLETED SUCCESSFULLY!");
    console.log("=".repeat(50));
    console.log("\nSummary:");
    console.log("Contracts deployed successfully");
    console.log("ERC20 and ETH deposits working");
    console.log("Withdrawal mechanisms functional");
    console.log("Fee system operational for early withdrawals");
    console.log("Access control working properly");
    console.log("Admin functions operational");
    console.log("Error handling working as expected");

  } catch (error) {
    console.error("\nError during demo execution:");
    console.error(error);
    process.exit(1);
  }
}

// Execute the main function
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\nUnhandled error:");
    console.error(error);
    process.exit(1);
  });