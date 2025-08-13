import { expect } from "chai";
import { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { MockERC20Permit, PermitSwap, MockUniswapRouter } from "../typechain-types";

describe("PermitSwap (ERC20 Permit Flow)", function () {
  let user: HardhatEthersSigner;
  let tokenA: MockERC20Permit;
  let tokenB: MockERC20Permit;
  let mockRouter: MockUniswapRouter;
  let permitSwap: PermitSwap;

  beforeEach(async () => {
    [user] = await ethers.getSigners();

    const MockRouterFactory = await ethers.getContractFactory("MockUniswapRouter");
    mockRouter = (await MockRouterFactory.deploy()) as MockUniswapRouter;

    const PermitSwapFactory = await ethers.getContractFactory("PermitSwap");
    permitSwap = (await PermitSwapFactory.deploy(mockRouter.target)) as PermitSwap;

    const TokenFactory = await ethers.getContractFactory("MockERC20Permit");
    tokenA = (await TokenFactory.deploy("TokenA", "TKA", 18)) as MockERC20Permit;
    tokenB = (await TokenFactory.deploy("TokenB", "TKB", 18)) as MockERC20Permit;

    // Mint tokens
    const mintAmount = ethers.parseEther("1000");
    await tokenA.mint(user.address, mintAmount);
    await tokenB.mint(user.address, mintAmount);

    // Optional: add pair to router if needed
  });

  it("should execute swap using ERC20 permit", async () => {
    const amountIn = ethers.parseEther("10");
    const amountOutMin = ethers.parseEther("9");
    const deadline = (await time.latest()) + 3600;

    // --- Sign ERC20 permit ---
    const tokenNonce = await tokenA.nonces(user.address);
    const tokenAaddress = await tokenA.getAddress();
    const domain = {
      name: await tokenA.name(),
      version: "1",
      chainId: (await user.provider.getNetwork()).chainId,
      verifyingContract: tokenAaddress,
    };
    const types = {
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
    const signature = ethers.Signature.from(await user.signTypedData(domain, types, permit));

    // --- Swap data ---
    const swapData = {
      owner: user.address,
      tokenIn: tokenA.target,
      tokenOut: tokenB.target,
      amountIn,
      amountOutMin,
      deadline,
    };

    const initialBalanceA = await tokenA.balanceOf(user.address);
    const initialBalanceB = await tokenB.balanceOf(user.address);

    // Execute swap
    await expect(
      permitSwap.swapWithPermit(swapData, signature.v, signature.r, signature.s)
    ).to.emit(permitSwap, "SwapExecuted");

    const finalBalanceA = await tokenA.balanceOf(user.address);
    const finalBalanceB = await tokenB.balanceOf(user.address);

    expect(finalBalanceA).to.equal(initialBalanceA - amountIn);
    expect(finalBalanceB).to.equal(initialBalanceB + amountIn); // mock rate=1
  });

  it("should revert with expired deadline", async () => {
    const amountIn = ethers.parseEther("10");
    const amountOutMin = ethers.parseEther("9");
    const deadline = (await time.latest()) - 10; // expired

    const tokenNonce = await tokenA.nonces(user.address);
    const tokenAaddress = await tokenA.getAddress();
    const domain = {
      name: await tokenA.name(),
      version: "1",
      chainId: (await user.provider.getNetwork()).chainId,
      verifyingContract: tokenAaddress,
    };
    const types = {
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
    const signature = ethers.Signature.from(await user.signTypedData(domain, types, permit));

    const swapData = {
      owner: user.address,
      tokenIn: tokenA.target,
      tokenOut: tokenB.target,
      amountIn,
      amountOutMin,
      deadline,
    };

    await expect(
      permitSwap.swapWithPermit(swapData, signature.v, signature.r, signature.s)
    ).to.be.revertedWithCustomError(permitSwap, "PermitSwap_SwapExpired");
  });
   it("should revert with invalid signature", async () => {
    const amountIn = ethers.parseEther("10");
    const amountOutMin = ethers.parseEther("9");
    const deadline = (await time.latest()) + 3600;

    const swapData = {
      owner: user.address,
      tokenIn: tokenA.target,
      tokenOut: tokenB.target,
      amountIn,
      amountOutMin,
      deadline,
    };

    // Sign with another account
    const [_, attacker] = await ethers.getSigners();
    const tokenNonce = await tokenA.nonces(user.address);
    const tokenAaddress = await tokenA.getAddress();
    const domain = {
      name: await tokenA.name(),
      version: "1",
      chainId: (await user.provider.getNetwork()).chainId,
      verifyingContract: tokenAaddress,
    };
    const types = {
      Permit: [
        { name: "owner", type: "address" },
        { name: "spender", type: "address" },
        { name: "value", type: "uint256" },
        { name: "nonce", type: "uint256" },
        { name: "deadline", type: "uint256" },
      ],
    };
    const invalidPermit = {
      owner: user.address,
      spender: permitSwap.target,
      value: amountIn,
      nonce: tokenNonce,
      deadline,
    };
    const invalidSig = ethers.Signature.from(await attacker.signTypedData(domain, types, invalidPermit));

    await expect(
      permitSwap.swapWithPermit(swapData, invalidSig.v, invalidSig.r, invalidSig.s)
    ).to.be.revertedWithCustomError(permitSwap, "PermitSwap_InvalidSignature");
  });
});
