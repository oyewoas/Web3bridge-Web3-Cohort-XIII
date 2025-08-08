// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {NFTStaking} from "../src/Staking.sol";
import {StakingToken} from "../src/StakingToken.sol";
import {RewardNFT} from "../src/RewardNFT.sol";

contract StakingScript is Script {
    NFTStaking public staking;
    StakingToken public stakingToken;
    RewardNFT public rewardNFT;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        // Deploy the Staking token contract
        stakingToken = new StakingToken("Staking Token", "STAK", 1000000 * 10 ** 18);
        // Deploy the reward NFT contract
        rewardNFT = new RewardNFT("MyRewardNFT", "MRNFT");
        staking = new NFTStaking(address(stakingToken), address(rewardNFT), 30 days);

        vm.stopBroadcast();
    }
}
