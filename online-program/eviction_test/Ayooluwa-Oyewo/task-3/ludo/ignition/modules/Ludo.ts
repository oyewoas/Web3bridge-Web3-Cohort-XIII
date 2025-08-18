import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("LudoGameModule", (m) => {
  const tokenAddress = "0xF73eb8f0b938D9c17aB726FDda632EDD43Ef640E";
  const stakeAmount = "1000000000000000000";

  // Deploy the LudoGame contract
  const ludoGame = m.contract("LudoGame", [tokenAddress, stakeAmount]);

  return { ludoGame };
});
