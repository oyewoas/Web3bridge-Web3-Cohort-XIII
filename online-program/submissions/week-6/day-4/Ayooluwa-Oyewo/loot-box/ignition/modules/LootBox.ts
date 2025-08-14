import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers } from "ethers";

export default buildModule("LootBoxModule", (m) => {
  const lootBox = m.contract("LootBox");

  m.call(lootBox, "createBox", [1, ethers.parseEther("1"), []]);

  return { lootBox };
});
