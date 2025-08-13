// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./MockERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockUniswapRouter {
    // Simple 1:1 swaps for testing
    event SwapExecuted(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut, address to);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        require(block.timestamp <= deadline, "Router: EXPIRED");
        require(path.length >= 2, "Invalid path");

        amounts = new uint[](path.length);
        amounts[0] = amountIn;

        for (uint i = 1; i < path.length; i++) {
            // 1:1 rate for simplicity
            amounts[i] = amounts[i-1];
        }

        require(amounts[amounts.length-1] >= amountOutMin, "Insufficient output");

        // Transfer input
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        // Mint output
        MockERC20Permit(path[path.length-1]).mint(to, amounts[amounts.length-1]);

        emit SwapExecuted(path[0], path[path.length-1], amountIn, amounts[amounts.length-1], to);
    }
}
