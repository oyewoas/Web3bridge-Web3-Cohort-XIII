import { ethers } from "hardhat";

const whale = "0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503";
const routerAddress = "0xf164fC0Ec4E93095b804a4795bBe1e041497b92a";
const factoryAddress = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f";
const usdtAddress = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
const daiAddress = "0x6B175474E89094C44Da98b954EedeAC495271d0F";

// swapping usdt for dai
async function swapExactTokensForToken(amount: bigint) {
  // get the signer
  const signer = await ethers.getImpersonatedSigner(whale);

  // check for the pair first
  const factoryContract = await ethers.getContractAt(
    "IUniswapV2Factory",
    factoryAddress,
    signer
  );
  let pairPoolAddress = await factoryContract.getPair(usdtAddress, daiAddress);

  if (pairPoolAddress == ethers.ZeroAddress) {
    console.log("Pool does not exist for this pair");
    process.exitCode = 1;
    process.exit();
  }

  // deal signer some eth to transact with
  const [deployer] = await ethers.getSigners();
  await deployer.sendTransaction({
    to: signer.address,
    value: ethers.parseEther("5"),
  });

  const routerContract = await ethers.getContractAt(
    "IUniswapV2Router01",
    routerAddress,
    signer
  );
  const usdtContract = await ethers.getContractAt(
    "IERC20",
    usdtAddress,
    signer
  );
  const daiContract = await ethers.getContractAt("IERC20", daiAddress, signer);

  const balanceOfDaiBeforeSwap = await daiContract.balanceOf(signer.address);
  const balanceOfUsdtBeforeSwap = await usdtContract.balanceOf(signer.address);

  console.log(
    `Balance of Dai before swap ${ethers.formatEther(balanceOfDaiBeforeSwap)}`
  );

  console.log(
    `Balance of Usdt before swap ${ethers.formatUnits(
      balanceOfUsdtBeforeSwap,
      6
    )}`
  );

  const amounts = await routerContract.getAmountsOut(amount, [
    usdtAddress,
    daiAddress,
  ]);
  const expectedDaiOut = amounts[1];
  const minDaiOut = (expectedDaiOut * 95n) / 100n;

  console.log(`Expected DAI out: ${ethers.formatEther(expectedDaiOut)}`);
  console.log(
    `Minimum DAI out (with slippage): ${ethers.formatEther(minDaiOut)}`
  );

  // approve router to chop your money
  await (await usdtContract.approve(routerAddress, amount)).wait();

  // call router and then perform swap
  await routerContract.swapExactTokensForTokens(
    amount,
    minDaiOut,
    [usdtAddress, daiAddress],
    signer.address,
    Math.ceil(Date.now() / 1000) + 300
  );

  const balanceOfDaiAfterSwap = await daiContract.balanceOf(signer.address);
  const balanceOfUsdtAfterSwap = await usdtContract.balanceOf(signer.address);
  console.log(
    `Balance of Dai after swap ${ethers.formatEther(balanceOfDaiAfterSwap)}`
  );
  console.log(
    `Balance of Usdt after swap ${ethers.formatUnits(
      balanceOfUsdtAfterSwap,
      6
    )}`
  );

  console.log(
    `Dai difference: ${ethers.formatEther(
      balanceOfDaiAfterSwap - balanceOfDaiBeforeSwap
    )}`
  );
  console.log(
    `Usdt difference: ${ethers.formatUnits(
      balanceOfUsdtBeforeSwap - balanceOfUsdtAfterSwap,
      6
    )}`
  );
}

swapExactTokensForToken(ethers.parseUnits("1000", 6)).catch((err) => {
  console.error(err);
  process.exitCode = 1;
});