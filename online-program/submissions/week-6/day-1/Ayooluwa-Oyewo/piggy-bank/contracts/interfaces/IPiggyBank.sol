// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IPiggyBank {
    function depositETH() external payable;

    function depositERC20(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function withdrawAll() external;
}