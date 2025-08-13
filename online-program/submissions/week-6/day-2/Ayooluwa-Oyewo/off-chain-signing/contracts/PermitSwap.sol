// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

import "./MockUniswapRouter.sol";

contract PermitSwap {
    MockUniswapRouter public immutable router;

    struct SwapData {
        address owner;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOutMin;
        uint256 deadline;
    }

    // events
    event SwapExecuted(
        address owner,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    event PermitUsed(
        address owner,
        address token,
        uint256 amount,
        uint256 deadline
    );
    // error handling
    error PermitSwap_SwapExpired();
    error PermitSwap_InvalidSignature();

 constructor(address _router) {
        router = MockUniswapRouter(_router);
    }
    function swapWithPermit(
        SwapData calldata swapData,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        if (block.timestamp > swapData.deadline) revert PermitSwap_SwapExpired();

        // Use ERC20 permit to approve this contract
        _permit(
            swapData.owner,
            swapData.tokenIn,
            swapData.amountIn,
            swapData.deadline,
            v,
            r,
            s
        );

        // Transfer token from user
        IERC20(swapData.tokenIn).transferFrom(
            swapData.owner,
            address(this),
            swapData.amountIn
        );

        // Approve router
        IERC20(swapData.tokenIn).approve(address(router), swapData.amountIn);

        // Perform swap
        address[] memory path = new address[](2);
        path[0] = swapData.tokenIn;
        path[1] = swapData.tokenOut;

        uint[] memory amounts = router.swapExactTokensForTokens(
            swapData.amountIn,
            swapData.amountOutMin,
            path,
            swapData.owner,
            swapData.deadline
        );

        emit SwapExecuted(
            swapData.owner,
            swapData.tokenIn,
            swapData.tokenOut,
            amounts[0],
            amounts[amounts.length - 1]
        );
    }

    function _permit(
        address owner,
        address token,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        try IERC20Permit(token).permit(
            owner,
            address(this),
            amount,
            deadline,
            v, r, s
        ){
            emit PermitUsed(owner, token, amount, deadline);
        } catch {
            revert PermitSwap_InvalidSignature();
        }
    }
}
