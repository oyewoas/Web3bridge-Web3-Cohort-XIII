// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const MultiSigWalletModule = buildModule("MultiSigWalletModule", (m) => {
    const requiredConfirmations = m.getParameter("requiredConfirmations", 2);
    const owners = m.getParameter("owners", [
        "0x5A232799eb8BBB999B1f056A0Ba0d8C7d5c1ebe0",
        "0x4E4E7e8ea62E6CD3568Eb218B38A8078EB83eD63",
    ]);

    const multiSigWallet = m.contract("MultiSigWallet", [owners, requiredConfirmations]);

    return { multiSigWallet };
});

export default MultiSigWalletModule;
