// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers } from "hardhat";

const TokenAModule = buildModule("TokenAModule", (m) => {
  const initialSupply = m.getParameter("initialSupply", ethers.parseEther("10000000000"));

  const tokenA = m.contract("TokenA", [initialSupply]);

  return { tokenA };
});

export default TokenAModule;
