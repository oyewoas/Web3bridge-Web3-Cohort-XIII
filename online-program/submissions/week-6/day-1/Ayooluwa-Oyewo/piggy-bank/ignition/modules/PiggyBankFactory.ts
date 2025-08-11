// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const PiggyBankFactoryModule = buildModule("PiggyBankFactoryModule", (m) => {
  const piggyBank = m.contract("PiggyBankFactory");

  return { piggyBank };
});

export default PiggyBankFactoryModule;
