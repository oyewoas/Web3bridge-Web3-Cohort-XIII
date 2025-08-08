// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {NFTStaking} from "../src/Staking.sol";
import {StakingToken} from "../src/StakingToken.sol";
import {RewardNFT} from "../src/RewardNFT.sol";
import "forge-std/console.sol";

contract StakingTest is Test {
    NFTStaking public staking;
    StakingToken public stakingToken;
    RewardNFT public rewardNFT;
    address public user = address(0x123);
    address public owner = address(0x456);

    function setUp() public {
        // Set up the owner
        vm.startPrank(owner);
        // Set up the environment
        // Deploy the staking token contract
        stakingToken = new StakingToken(
            "Staking Token",
            "STAK",
            1000000 * 10 ** 18
        );
        // Deploy the reward NFT contract
        rewardNFT = new RewardNFT("MyRewardNFT", "MRNFT");
        // Deploy the Staking contract
        staking = new NFTStaking(
            address(stakingToken),
            address(rewardNFT),
            30 days
        );
        
        vm.stopPrank();
    }

    function test_deployment() public view {
        // assertEq(staking.stakingToken().name(), "Staking Token");
        // assertEq(staking.stakingToken().symbol(), "STAK");
        assertEq(staking.stakingToken().totalSupply(), 1000000 * 10 ** 18);
        assertEq(staking.rewardNFT().name(), "MyRewardNFT");
        assertEq(staking.rewardNFT().symbol(), "MRNFT");
        assertEq(staking.lockPeriod(), 30 days);
    }
    function test_staking_reverts() public {
        // Test staking functionality
        // Check invalid amount
        vm.expectRevert(NFTStaking.NFTStaking_InvalidAmount.selector);
        staking.stake(0);

        // Check case where balance of user is less than amount
        vm.expectRevert(NFTStaking.NFTStaking_NotEnoughTokens.selector);
        staking.stake(2);

        // Give user tokens
        vm.prank(owner);
        stakingToken.mint(user, 9);

        vm.startPrank(user);
        stakingToken.approve(address(staking), 2);

        // First stake — should succeed
        staking.stake(2);

        // Second stake — should revert as already staked
        vm.expectRevert(NFTStaking.NFTStaking_AlreadyStaked.selector);
        staking.stake(1);
        vm.stopPrank();
    }

    function test_staking() public {
        // Test staking functionality
        // Mint tokens to user
        vm.prank(owner);
        stakingToken.mint(user, 2);

        vm.startPrank(user);
        stakingToken.approve(address(staking), 2);
        // Emit
        vm.expectEmit(true, true, true, false);
        emit NFTStaking.Staked(user, 2, 0);
        staking.stake(2);
        // Check stake info
        (uint256 amount, uint256 unlockTime, uint256 tokenId) = staking.stakes(user);
        assertEq(amount, 2);
        assertEq(unlockTime, block.timestamp + 30 days);
        assertEq(tokenId, 0);
        assertEq(stakingToken.balanceOf(user), 0);
        assertEq(rewardNFT.balanceOf(user), 1);
        vm.stopPrank();

    }
    function test_unstaking_reverts() public {
        // Test unstaking functionality
        vm.startPrank(user);
        // Check case where user has not staked
        vm.expectRevert(NFTStaking.NFTStaking_NotStaked.selector);
        staking.unstake();
        vm.stopPrank(); 

        vm.prank(owner);
        stakingToken.mint(user, 2);

        vm.startPrank(user);
        stakingToken.approve(address(staking), 2);
        staking.stake(2);
        // Check case where lock period is not over
        vm.expectRevert(NFTStaking.NFTStaking_LockPeriodNotOver.selector);
        staking.unstake();
        vm.stopPrank();
    }

    function test_unstaking() public {
        // Test unstaking functionality
        vm.prank(owner);
        stakingToken.mint(user, 2);

        vm.startPrank(user);
        stakingToken.approve(address(staking), 2);
        staking.stake(2);

        // Fast forward time to unlock period
        vm.warp(block.timestamp + 30 days + 1);

        // Emit
        vm.expectEmit(true, true, true, false);
        emit NFTStaking.Unstaked(user, 2, 0);
        staking.unstake();

        // Check stake info
        (uint256 amount, uint256 unlockTime, uint256 tokenId) = staking.stakes(user);
        assertEq(amount, 0);
        assertEq(unlockTime, 0);
        assertEq(tokenId, 0);
        assertEq(stakingToken.balanceOf(user), 2);
        assertEq(rewardNFT.balanceOf(user), 0);
        vm.stopPrank();
    }

}
