// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Staking} from "../src/Staking.sol";

contract StakingTest is Test {
    Staking public staking;

    function setUp() public {
        // Deploy the staking token contract
        stakingToken = new StakingToken("Staking Token", "STAK", 1000000 * 10 ** 18);
        // Deploy the reward NFT contract
        rewardNFT = new MyRewardNFT("MyRewardNFT", "MRNFT");
        // Deploy the Staking contract
        staking = new Staking(stakingToken, rewardNFT, 30 days);
    }

    function test_deployment() public {
        assertEq(staking.stakingToken().name(), "Staking Token");
        assertEq(staking.stakingToken().symbol(), "STAK");
        assertEq(staking.stakingToken().totalSupply(), 1000000 * 10 ** 18);
        assertEq(staking.rewardNFT().name(), "MyRewardNFT");
        assertEq(staking.rewardNFT().symbol(), "MRNFT");
        assertEq(staking.lockPeriod(), 30 days);
    }
}
