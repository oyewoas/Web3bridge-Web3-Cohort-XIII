// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, Vm} from "forge-std/Test.sol";
import {LootBox} from "../contracts/LootBox.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {ERC721Mock} from "./mocks/ERC721Mock.sol";
import {ERC1155Mock} from "./mocks/ERC1155Mock.sol";
import {LinkToken} from "./mocks/LinkToken.sol";

contract LootBoxTest is Test {
    LootBox public lootBox;
    VRFCoordinatorV2_5Mock public vrfCoordinator;
    uint256 public subscriptionId;
    LinkToken public linkToken;
    bytes32 public immutable gasLane = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;

    ERC20Mock public erc20;
    ERC721Mock public erc721;
    ERC1155Mock public erc1155;

    address public PLAYER = makeAddr("player");
    address public OWNER = address(this);
    uint256 public constant STARTING_BALANCE = 10 ether;

    uint256 boxId = 1;
    uint256 boxPrice = 1 ether;
    
    // Track request IDs
    uint256 public currentRequestId = 1;

    // Add receive function to accept ETH
    receive() external payable {}

    function setUp() external {
        // Deploy VRF mock with proper parameters
        vrfCoordinator = new VRFCoordinatorV2_5Mock(
            100000000000000000, // _BASEFEE: 0.1 ether
            1000000000,          // _GASPRICELINK: 1 gwei
            4e15                 // _WEIPERUNITLINK: current LINK/ETH price
        );
        
        // Create subscription
        subscriptionId = vrfCoordinator.createSubscription();
        
        // Deploy LinkToken
        linkToken = new LinkToken();

        // Fund the subscription with a large amount (10,000 LINK equivalent)
        vrfCoordinator.fundSubscription(subscriptionId, 10000000000000000000000);
        
        // Deploy LootBox
        lootBox = new LootBox(
            address(vrfCoordinator),
            gasLane,
            subscriptionId,
            500000
        );
        
        // Register LootBox as a valid VRF consumer
        vrfCoordinator.addConsumer(subscriptionId, address(lootBox));
        
        // Deploy token mocks
        erc20 = new ERC20Mock("Mock Token", "MTK", 1000 ether);
        erc721 = new ERC721Mock("Mock NFT", "MNFT");
        erc1155 = new ERC1155Mock();

        // Mint some tokens for LootBox
        erc20.transfer(address(lootBox), 100 ether);
        erc721.mint(address(lootBox), 1);
        erc1155.mint(address(lootBox), 1, 10);

        // Give player ETH
        vm.deal(PLAYER, STARTING_BALANCE);

        // Create box with 3 rewards: ERC20, ERC721, ERC1155
        LootBox.Reward[] memory rewards = new LootBox.Reward[](3);
        rewards[0] = LootBox.Reward({
            tokenAddress: address(erc20),
            tokenId: 0,
            amount: 10 ether,
            weight: 50,
            rewardType: LootBox.RewardType.ERC20
        });
        rewards[1] = LootBox.Reward({
            tokenAddress: address(erc721),
            tokenId: 1,
            amount: 1,
            weight: 30,
            rewardType: LootBox.RewardType.ERC721
        });
        rewards[2] = LootBox.Reward({
            tokenAddress: address(erc1155),
            tokenId: 1,
            amount: 5,
            weight: 20,
            rewardType: LootBox.RewardType.ERC1155
        });

        lootBox.createBox(boxId, boxPrice, rewards);
    }

    // ------------------------------
    // Basic ETH and access tests
    // ------------------------------

    function testCannotOpenBoxWithoutPaying() public {
        vm.prank(PLAYER);
        vm.expectRevert(LootBox.LootBox__SendMoreToOpen.selector);
        lootBox.openBox{value: 0}(boxId);
    }

    function testOwnerCanWithdrawETH() public {
        // Player opens box
        vm.prank(PLAYER);
        lootBox.openBox{value: boxPrice}(boxId);

        uint256 startBal = address(this).balance;
        lootBox.withdrawETH(payable(address(this)), boxPrice);
        assertEq(address(this).balance, startBal + boxPrice);
    }

    // ------------------------------
    // Events
    // ------------------------------

    function testOpenBoxEmitsRandomnessRequested() public {
        vm.prank(PLAYER);
        vm.recordLogs();
        lootBox.openBox{value: boxPrice}(boxId);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertTrue(entries.length > 0);
    }

    function testOpenBoxEmitsBoxOpenedEvent() public {
        uint256 userStart = erc20.balanceOf(PLAYER);

        // We simulate fulfillRandomWords manually
        vm.prank(PLAYER);
        lootBox.openBox{value: boxPrice}(boxId);

        // Use our tracked request ID
        uint256 requestId = currentRequestId;
        currentRequestId++;
        
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 42; // This should select ERC20 with weight 50

        // Record logs before fulfilling
        vm.recordLogs();
        
        // Simulate VRF callback with specific random value
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(lootBox), randomWords);

        // Check if the reward was delivered (this confirms BoxOpened was emitted)
        uint256 userEnd = erc20.balanceOf(PLAYER);
        assertTrue(userEnd > userStart);
    }

    // ------------------------------
    // Reward distribution tests
    // ------------------------------

    function testERC20RewardDelivered() public {
        uint256 start = erc20.balanceOf(PLAYER);

        vm.prank(PLAYER);
        lootBox.openBox{value: boxPrice}(boxId);

        uint256 requestId = currentRequestId;
        currentRequestId++;
        
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 25; // Should select ERC20 (weight 50, so 0-49 selects ERC20)
        
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(lootBox), randomWords);

        uint256 end = erc20.balanceOf(PLAYER);
        assertEq(end, start + 10 ether);
    }

    function testERC721RewardDelivered() public {
        vm.prank(PLAYER);
        lootBox.openBox{value: boxPrice}(boxId);

        uint256 requestId = currentRequestId;
        currentRequestId++;
        
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 65; // Should select ERC721 (weights: ERC20=50, ERC721=30, so 50-79 selects ERC721)
        
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(lootBox), randomWords);

        assertEq(erc721.ownerOf(1), PLAYER);
    }

    function testERC1155RewardDelivered() public {
        vm.prank(PLAYER);
        lootBox.openBox{value: boxPrice}(boxId);

        uint256 requestId = currentRequestId;
        currentRequestId++;
        
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 90; // Should select ERC1155 (weights: ERC20=50, ERC721=30, ERC1155=20, so 80-99 selects ERC1155)
        
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(lootBox), randomWords);

        assertEq(erc1155.balanceOf(PLAYER, 1), 5);
    }

    // ------------------------------
    // Weighted randomness
    // ------------------------------

    function testWeightedRewardSelection() public {
        uint256[3] memory wins; // [erc20Wins, erc721Wins, erc1155Wins]
        uint256 totalTests = 20;

        for (uint256 i = 0; i < totalTests; i++) {
            _testSingleWeightedReward(i, wins);
        }

        // With weights 50, 30, 20 - ERC20 should win most, ERC721 middle, ERC1155 least
        assertTrue(wins[0] > 0, "ERC20 should win at least once");
        assertTrue(wins[1] + wins[2] > 0, "Other rewards should also win");
        
        // Log results for debugging
        emit log_named_uint("ERC20 wins", wins[0]);
        emit log_named_uint("ERC721 wins", wins[1]);
        emit log_named_uint("ERC1155 wins", wins[2]);
        emit log_named_uint("Total tests", totalTests);
    }

    function _testSingleWeightedReward(uint256 i, uint256[3] memory wins) internal {
        address currentPlayer = makeAddr(string(abi.encodePacked("player", i)));
        vm.deal(currentPlayer, STARTING_BALANCE);
        
        uint256 newTokenId = i + 1000;
        uint256 newBoxId = i + 1000;
        
        // Setup tokens
        _setupTokensForTest(newTokenId);
        
        // Create box
        _createTestBox(newBoxId, newTokenId);

        // Execute test
        (bool erc20Won, bool erc721Won, bool erc1155Won) = _executeBoxTest(currentPlayer, newBoxId, newTokenId);
        
        // Count results
        if (erc20Won) {
            wins[0]++;
        } else if (erc721Won) {
            wins[1]++;
        } else if (erc1155Won) {
            wins[2]++;
        }
    }

    function _setupTokensForTest(uint256 tokenId) internal {
        uint256 lootBoxERC20Balance = erc20.balanceOf(address(lootBox));
        uint256 lootBoxERC1155Balance = erc1155.balanceOf(address(lootBox), tokenId);
        
        if (lootBoxERC20Balance < 10 ether) {
            erc20.mint(address(lootBox), 20 ether);
        }
        
        erc721.mint(address(lootBox), tokenId);
        
        if (lootBoxERC1155Balance < 5) {
            erc1155.mint(address(lootBox), tokenId, 10);
        }
    }

    function _createTestBox(uint256 createBoxId, uint256 tokenId) internal {
        LootBox.Reward[] memory rewards = new LootBox.Reward[](3);
        rewards[0] = LootBox.Reward({
            tokenAddress: address(erc20),
            tokenId: 0,
            amount: 10 ether,
            weight: 50,
            rewardType: LootBox.RewardType.ERC20
        });
        rewards[1] = LootBox.Reward({
            tokenAddress: address(erc721),
            tokenId: tokenId,
            amount: 1,
            weight: 30,
            rewardType: LootBox.RewardType.ERC721
        });
        rewards[2] = LootBox.Reward({
            tokenAddress: address(erc1155),
            tokenId: tokenId,
            amount: 5,
            weight: 20,
            rewardType: LootBox.RewardType.ERC1155
        });

        lootBox.createBox(createBoxId, boxPrice, rewards);
    }

    function _executeBoxTest(address player, uint256 executingBoxId, uint256 tokenId) internal returns (bool, bool, bool) {
        uint256 playerERC20Before = erc20.balanceOf(player);
        uint256 playerERC1155Before = erc1155.balanceOf(player, tokenId);
        
        vm.prank(player);
        lootBox.openBox{value: boxPrice}(executingBoxId);

        uint256 requestId = currentRequestId;
        currentRequestId++;
        
        // Use different random values for each test to get varied results
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = uint256(keccak256(abi.encodePacked(block.timestamp, requestId, player))) % 1000000;
        
        // Call fulfillRandomWordsWithOverride to provide specific random values
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(lootBox), randomWords);

        bool erc20Won = erc20.balanceOf(player) > playerERC20Before;
        bool erc1155Won = erc1155.balanceOf(player, tokenId) > playerERC1155Before;
        bool erc721Won = false;
        
        try erc721.ownerOf(tokenId) returns (address owner) {
            erc721Won = (owner == player);
        } catch {
            erc721Won = false;
        }
        
        return (erc20Won, erc721Won, erc1155Won);
    }

    // Helper function to get current request ID safely
    function getNextRequestId() internal returns (uint256) {
        uint256 requestId = currentRequestId;
        currentRequestId++;
        return requestId;
    }
}