// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library Errors {
    error PiggyBank__InsufficientFunds();
    error PiggyBank__UnauthorizedAccess();
    error PiggyBank__InvalidLockPeriod();
    error PiggyBank__CanOnlyReceiveETH();
    error PiggyBank__CanOnlyReceiveERC20();
    error PiggyBank__FeeTransferFailed();
    error PiggyBank__TransferFailed();
    error PiggyBank__SavingsPlanInactive();
    error PiggyBank__ZeroAddress();
    error PiggyBank__ZeroValue();
}