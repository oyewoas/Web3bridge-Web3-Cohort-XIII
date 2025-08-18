// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, Vm} from "forge-std/Test.sol";
import {Lottery} from "../contracts/Lottery.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "./mocks/LinkToken.sol";
import {console} from "forge-std/console.sol";

contract LotteryTest is Test {
    Lottery public lottery;
    VRFCoordinatorV2_5Mock public vrfCoordinator;
    LinkToken public linkToken;
    uint256 public subscriptionId;

    address public OWNER = address(this);
    address public PLAYER1 = makeAddr("player1");
    address public PLAYER2 = makeAddr("player2");
    address public PLAYER3 = makeAddr("player3");

    bytes32 public immutable gasLane =
        0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;

    uint256 constant START_BAL = 10 ether;

    receive() external payable {}

    function setUp() external {
        // Deploy VRF mock
        vrfCoordinator = new VRFCoordinatorV2_5Mock(
            100000000000000000, // base fee
            1000000000, // gas price link
            4e15 // link/eth
        );

        subscriptionId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subscriptionId, 100 ether);

        linkToken = new LinkToken();

        // Deploy Lottery
        lottery = new Lottery(
            address(vrfCoordinator),
            gasLane,
            subscriptionId,
            500000
        );

        vrfCoordinator.addConsumer(subscriptionId, address(lottery));

        // Fund players
        vm.deal(PLAYER1, START_BAL);
        vm.deal(PLAYER2, START_BAL);

        // Enable lottery
        lottery.toggleLottery();
    }

    // ------------------------------
    // Join flow
    // ------------------------------

    function testCannotJoinWithoutActiveLottery() public {
        lottery.toggleLottery(); // turn off
        vm.prank(PLAYER1);
        vm.expectRevert(Lottery.LotteryNotActive.selector);
        lottery.enterLottery{value: 0.01 ether}();
    }

    function testCannotJoinWithWrongFee() public {
        vm.prank(PLAYER1);
        vm.expectRevert(Lottery.InvalidEntryFee.selector);
        lottery.enterLottery{value: 0.02 ether}();
    }

    function testPlayerCanJoin() public {
        vm.prank(PLAYER1);
        lottery.enterLottery{value: 0.01 ether}();

        address[] memory players = lottery.getPlayers();
        assertEq(players.length, 1);
        assertEq(players[0], PLAYER1);
        assertTrue(lottery.hasPlayerEntered(PLAYER1));
    }

    function testCannotJoinTwice() public {
        vm.startPrank(PLAYER1);
        lottery.enterLottery{value: 0.01 ether}();
        vm.expectRevert(Lottery.AlreadyEntered.selector);
        lottery.enterLottery{value: 0.01 ether}();
        vm.stopPrank();
    }

    // ------------------------------
    // Max players + randomness
    // ------------------------------

    function testRequestRandomnessAtMaxPlayers() public {

        // use unique players
        uint256 maxPlayers = lottery.MAX_PLAYERS();
    for (uint256 i = 0; i < maxPlayers; i++) {
        address player = address(uint160(i + 1)); // unique address
        vm.deal(player, 1 ether);
        vm.startPrank(player);
        lottery.enterLottery{value: lottery.ENTRY_FEE()}();
        console.log("Entering lottery for player:", player);
        vm.stopPrank();
    }

    // At this point MAX_PLAYERS have joined, so VRF request should have been triggered
    assertTrue(lottery.pendingWinnerSelection());
    assertEq(lottery.getPlayerCount(), maxPlayers);
    }


    function testFulfillRandomWordsSelectsWinnerAndPaysPrize() public {
        // Fill all 10 players
        address[] memory testPlayers = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            testPlayers[i] = makeAddr(string(abi.encodePacked("p", i)));
            vm.deal(testPlayers[i], START_BAL);
            vm.prank(testPlayers[i]);
            lottery.enterLottery{value: 0.01 ether}();
        }

        uint256 prizePool = address(lottery).balance;
        assertEq(prizePool, 0.1 ether);

        // Simulate randomness
        uint256 requestId = 1; // VRFMock always increments from 1
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 5; // deterministic winner index

        // Capture logs
        vm.recordLogs();

        vrfCoordinator.fulfillRandomWordsWithOverride(
            requestId,
            address(lottery),
            randomWords
        );
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Should have WinnerSelected + LotteryReset events
        assertGt(entries.length, 0);

        // Check winner got paid
        address winner = testPlayers[5 % 10];
        assertEq(lottery.getRoundWinner(0), winner);
        assertEq(winner.balance, START_BAL + prizePool);
        assertEq(address(lottery).balance, 0);

        // Lottery reset
        (, uint256 playerCount, , , bool pending) = lottery.getContractState();
        assertEq(playerCount, 0);
        assertFalse(pending);
    }

    // ------------------------------
    // Admin functions
    // ------------------------------

    function testOnlyOwnerCanManualRequest() public {
        // Fill 10 players
        for (uint256 i = 0; i < 10; i++) {
            address p = makeAddr(string(abi.encodePacked("p", i)));
            vm.deal(p, START_BAL);
            vm.prank(p);
            lottery.enterLottery{value: 0.01 ether}();
        }

        // Non-owner cannot call
        vm.prank(PLAYER1);
        vm.expectRevert(); // OnlyOwner()
        lottery.manualRequestWinner();

        // Owner can call
        lottery.manualRequestWinner();
    }

    function testEmergencyResetClearsPlayers() public {
        vm.prank(PLAYER1);
        lottery.enterLottery{value: 0.01 ether}();
        vm.prank(PLAYER2);
        lottery.enterLottery{value: 0.01 ether}();

        lottery.emergencyReset();

        assertEq(lottery.getPlayerCount(), 0);
    }

    function testToggleLotteryWorks() public {
        (, , , bool active, ) = lottery.getContractState();
        assertTrue(active);

        lottery.toggleLottery();
        (, , , active, ) = lottery.getContractState();
        assertFalse(active);
    }

    function testUpdateSubscriptionIdAndConfig() public {
        lottery.updateSubscriptionId(77);
        assertEq(lottery.s_subscriptionId(), 77);

        lottery.updateVRFConfig(
            bytes32("abc"),
            123,
            3
        );
    }

    // ------------------------------
    // Fallback / Receive
    // ------------------------------

    function testDirectEthRejected() public {
        vm.expectRevert(Lottery.DirectEthNotAllowed.selector);
        (bool ok, ) = address(lottery).call{value: 1 ether}("");
        ok;
    }
}
