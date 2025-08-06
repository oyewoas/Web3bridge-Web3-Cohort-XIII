// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const StakingModule = buildModule("StakingModule", (m) => {
  // Deployed lisk sepolia token A and B addresses
  const tokenA = m.getParameter("tokenA", "0x6c01A4FeEa3076a013c855cc08B313ebce637965");
  const tokenB = m.getParameter("tokenB", "0x06ddFcb085F1Ea97a23ea6d6EC245c730368d16F");
  const lockPeriod = m.getParameter("lockPeriod", 30 * 24 * 60 * 60);

  const staking = m.contract("Staking", [tokenA, tokenB, lockPeriod]);

  return { staking };
});

export default StakingModule;
