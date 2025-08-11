/**
Piggy Bank Factory
Objective
Build a piggy bank that allow users to Join and create multiple savings account
Allow them to save either ERC20 or Ethers: they should be able to choose.
Make it a Factory
We must be able to get the balance of each user and make the deployer of the factory the admin.
Track how many savings account the account have.
Track the lock period for each savings plan that a user has on their child contract and they must have different lock periods.
And if they intend to withdraw before the lock period that should incur a 3% breaking fee that would be transferred to the account of the deployer of the factory.
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./PiggyBank.sol";
import "./libraries/Events.sol";
import "./interfaces/IPiggyBankFactory.sol";
import "hardhat/console.sol";


contract PiggyBankFactory is IPiggyBankFactory {
    address public admin;
    PiggyBank[] public piggyBanks;
    mapping(address userAddress => address[] savingAccounts) public userSavingsAccounts;
    mapping(address userAddress => mapping(address savingAccount => uint256 lockPeriod)) public userSavingsLockPeriod;
    mapping(address userAddress => uint256 savingsCount) public userSavingsCount;

    constructor() {
        admin = msg.sender;
    }

    function createPiggyBank(
        uint256 targetAmount,
        address tokenAddress,
        uint256 lockPeriod
    ) external returns (address) {
        PiggyBank newPiggyBank = new PiggyBank(msg.sender, targetAmount, tokenAddress, lockPeriod, admin, address(this));
        address newSavingsAccount = address(newPiggyBank);
        piggyBanks.push(newPiggyBank);
        userSavingsAccounts[msg.sender].push(newSavingsAccount);
        userSavingsCount[msg.sender]++;
        userSavingsLockPeriod[msg.sender][newSavingsAccount] = lockPeriod;
        emit Events.PiggyBankCreated(msg.sender, newSavingsAccount);
        return newSavingsAccount;
    }

    function pfGetAllPiggyBanks(uint256 limit, uint256 offset) external view returns (PiggyBank[] memory) {
        if (offset >= piggyBanks.length) {
            return new PiggyBank[](0);
        }

        uint256 end = offset + limit;
        if (end > piggyBanks.length) {
            end = piggyBanks.length;
        }

        PiggyBank[] memory result = new PiggyBank[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = piggyBanks[i];
        }
        return result;
    }

    // Getters
    function pfGetPiggyBanksCount() external view returns (uint256) {
        return piggyBanks.length;
    }

    function pfGetUserSavingsAccounts(address user) external view returns (address[] memory) {
        return userSavingsAccounts[user];
    }

    function pfGetSavingsBalance(address savingsAccount) external view returns (uint256) {
        PiggyBank piggyBank = PiggyBank(savingsAccount);
        (, , , uint256 balance, , , ) = piggyBank.savingsPlan();
        return balance;
    }

    function pfGetUserSavingsLockPeriod(address user, address savingsAccount) external view returns (uint256) {
        return userSavingsLockPeriod[user][savingsAccount];
    }

    function pfGetUserSavingsCount(address user) external view returns (uint256) {
        return userSavingsCount[user];
    }
}