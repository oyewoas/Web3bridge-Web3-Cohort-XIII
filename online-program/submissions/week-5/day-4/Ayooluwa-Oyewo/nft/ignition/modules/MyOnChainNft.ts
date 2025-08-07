// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const MyNftModule = buildModule("MyNftModule", (m) => {
  const myNft = m.contract("MyOnChainNft", []);
  return { myNft };
});

export default MyNftModule;
