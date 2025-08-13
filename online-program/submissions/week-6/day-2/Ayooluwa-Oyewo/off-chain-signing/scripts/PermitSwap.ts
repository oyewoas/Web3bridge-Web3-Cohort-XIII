import { ethers } from "hardhat";

async function main() {
  const [deployer, user] = await ethers.getSigners();

  console.log("Deploying contracts with account:", deployer.address);

  // Deploy Mock Router
  const RouterFactory = await ethers.getContractFactory("MockUniswapRouter");
  const mockRouter = await RouterFactory.deploy();
  console.log("MockRouter deployed to:", mockRouter.target);

  // Deploy Mock ERC20Permit tokens
  const TokenFactory = await ethers.getContractFactory("MockERC20Permit");
  const tokenA = await TokenFactory.deploy("TokenA", "TKA", 18);
  const tokenB = await TokenFactory.deploy("TokenB", "TKB", 18);
  console.log("TokenA deployed to:", tokenA.target);
  console.log("TokenB deployed to:", tokenB.target);

  // Mint tokens to user
  const mintAmount = ethers.parseEther("1000");
  await tokenA.mint(user.address, mintAmount);
  await tokenB.mint(user.address, mintAmount);
  console.log("Minted tokens to user:", user.address);

  // Deploy PermitSwap
  const PermitSwapFactory = await ethers.getContractFactory("PermitSwap");
  const permitSwap = await PermitSwapFactory.deploy(mockRouter.target);
  console.log("PermitSwap deployed to:", permitSwap.target);

  // === Prepare swap ===
  const amountIn = ethers.parseEther("10");
  const amountOutMin = ethers.parseEther("9");
  const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

  // ERC20 Permit signature
  const tokenNonce = await tokenA.nonces(user.address);
  const tokenAaddress = await tokenA.getAddress();
  const tokenDomain = {
    name: await tokenA.name(),
    version: "1",
    chainId: (await user.provider.getNetwork()).chainId,
    verifyingContract: tokenAaddress,
  };
  const tokenTypes = {
    Permit: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
      { name: "value", type: "uint256" },
      { name: "nonce", type: "uint256" },
      { name: "deadline", type: "uint256" },
    ],
  };
  const permit = {
    owner: user.address,
    spender: permitSwap.target,
    value: amountIn,
    nonce: tokenNonce,
    deadline,
  };

  const signature = await user.signTypedData(tokenDomain, tokenTypes, permit);
  const sig = ethers.Signature.from(signature);

  // Swap data
  const swapData = {
    owner: user.address,
    tokenIn: tokenA.target,
    tokenOut: tokenB.target,
    amountIn,
    amountOutMin,
    deadline,
  };

  // Execute swap
  const tx = await permitSwap.connect(user).swapWithPermit(swapData, sig.v, sig.r, sig.s);
  const receipt = await tx.wait();

  console.log("Swap executed in tx:", receipt?.hash);

  // Check balances
  const balanceA = await tokenA.balanceOf(user.address);
  const balanceB = await tokenB.balanceOf(user.address);
  console.log("User TokenA balance:", balanceA.toString());
  console.log("User TokenB balance:", balanceB.toString());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
