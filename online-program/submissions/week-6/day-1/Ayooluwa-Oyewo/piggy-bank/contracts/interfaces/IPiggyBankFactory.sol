// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import "../PiggyBank.sol"; // Adjust the path as needed to where PiggyBank is defined

interface IPiggyBankFactory {
    function createPiggyBank(
        uint256 targetAmount,
        address tokenAddress,
        uint256 lockPeriod
    ) external returns (address);

    function pfGetAllPiggyBanks(uint256 limit, uint256 offset) external view returns (PiggyBank[] memory);

    function pfGetPiggyBanksCount() external view returns (uint256);

    function pfGetUserSavingsAccounts(address user) external view returns (address[] memory);

    function pfGetSavingsBalance(address savingsAccount) external view returns (uint256);

    function pfGetUserSavingsLockPeriod(address user, address savingsAccount) external view returns (uint256);

    function pfGetUserSavingsCount(address user) external view returns (uint256);
}