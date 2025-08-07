// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Staking} from "../src/Staking.sol";

contract StakingScript is Script {
    Staking public staking;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        // Deploy the Staking token contract
        stakingToken = new StakingToken("Staking Token", "STAK", 1000000 * 10 ** 18);
        // Deploy the reward NFT contract
        rewardNFT = new MyRewardNFT("MyRewardNFT", "MRNFT");
        staking = new Staking(stakingToken, rewardNFT, 30 days);

        vm.stopBroadcast();
    }
}
