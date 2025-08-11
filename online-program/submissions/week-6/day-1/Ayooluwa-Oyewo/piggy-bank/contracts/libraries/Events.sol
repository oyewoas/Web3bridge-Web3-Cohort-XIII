// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library Events {
    event SavingsPlanCreated(
        address indexed owner,
        uint256 targetAmount,
        address tokenAddress,
        uint256 lockPeriod
    );
    event SavingsPlanFunded(address indexed owner, uint256 amount);
    event SavingsPlanWithdrawn(address indexed owner, uint256 amount);
    event SavingsTargetReached(address indexed owner, uint256 amount);
    event PiggyBankCreated(address indexed owner, address indexed piggyBank);
}
