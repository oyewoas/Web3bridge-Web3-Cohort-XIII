// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title Loot Box / Mystery Box Contract
 * @notice Pay ETH to open a box and receive a random reward instantly
 * @dev Supports ERC20, ERC721, ERC1155 with weighted chances
 */
contract LootBox is VRFConsumerBaseV2Plus, IERC1155Receiver, IERC721Receiver {
    /* Errors */
    error LootBox__SendMoreToOpen();
    error LootBox__NoRewardsConfigured();
    error LootBox__TransferFailed();

    /* Type declarations */
    enum RewardType { ERC20, ERC721, ERC1155 }

    struct Reward {
        address tokenAddress;
        uint256 tokenId; // for ERC721 & ERC1155
        uint256 amount;  // for ERC20 & ERC1155
        uint16 weight;   // relative chance
        RewardType rewardType;
    }

    struct Box {
        uint256 price; // fee in ETH
        Reward[] rewards;
        uint16 totalWeight;
    }

    /* State variables */
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    mapping(uint256 => Box) private s_boxes;             // boxId => Box
    mapping(uint256 => address) private s_requestToSender; // requestId => user
    mapping(uint256 => uint256) private s_requestToBoxId;  // requestId => boxId

    /* Events */
    event BoxCreated(uint256 indexed boxId);
    event BoxOpened(address indexed user, uint256 indexed boxId, Reward reward);
    event RandomnessRequested(uint256 indexed requestId, address indexed user);

    /* Constructor */
    constructor(
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    /* External functions */

    function createBox(uint256 boxId, uint256 price, Reward[] memory rewards) external onlyOwner {
        require(rewards.length > 0, "Must have at least one reward");
        
        // Clear existing rewards if any
        delete s_boxes[boxId];
        
        Box storage box = s_boxes[boxId];
        box.price = price;

        uint16 totalWeight = 0;
        for (uint256 i = 0; i < rewards.length; i++) {
            box.rewards.push(rewards[i]);
            totalWeight += rewards[i].weight;
        }

        box.totalWeight = totalWeight;

        emit BoxCreated(boxId);
    }

    function openBox(uint256 boxId) external payable {
        Box storage box = s_boxes[boxId];
        if (msg.value < box.price) revert LootBox__SendMoreToOpen();
        if (box.rewards.length == 0) revert LootBox__NoRewardsConfigured();

        // Request randomness from Chainlink VRF
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false}) // Changed to false for testing
            )
        });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        s_requestToSender[requestId] = msg.sender;
        s_requestToBoxId[requestId] = boxId;

        emit RandomnessRequested(requestId, msg.sender);
    }

    /* Internal functions */

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        address user = s_requestToSender[requestId];
        uint256 boxId = s_requestToBoxId[requestId];
        Box storage box = s_boxes[boxId];

        // Clean up mappings
        delete s_requestToSender[requestId];
        delete s_requestToBoxId[requestId];

        uint256 rand = randomWords[0] % box.totalWeight;
        uint16 cumulativeWeight = 0;
        Reward memory selectedReward;

        for (uint256 i = 0; i < box.rewards.length; i++) {
            cumulativeWeight += box.rewards[i].weight;
            if (rand < cumulativeWeight) {
                selectedReward = box.rewards[i];
                break;
            }
        }

        // Send reward
        if (selectedReward.rewardType == RewardType.ERC20) {
            bool success = IERC20(selectedReward.tokenAddress).transfer(user, selectedReward.amount);
            if (!success) revert LootBox__TransferFailed();
        } else if (selectedReward.rewardType == RewardType.ERC721) {
            IERC721(selectedReward.tokenAddress).safeTransferFrom(address(this), user, selectedReward.tokenId);
        } else if (selectedReward.rewardType == RewardType.ERC1155) {
            IERC1155(selectedReward.tokenAddress).safeTransferFrom(
                address(this),
                user,
                selectedReward.tokenId,
                selectedReward.amount,
                ""
            );
        }

        emit BoxOpened(user, boxId, selectedReward);
    }

    /* Owner functions */
    function withdrawETH(address payable to, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        (bool success, ) = to.call{value: amount}("");
        require(success, "Transfer failed");
    }

    /* View functions */
    function getBox(uint256 boxId) external view returns (Box memory) {
        return s_boxes[boxId];
    }

    function getBoxPrice(uint256 boxId) external view returns (uint256) {
        return s_boxes[boxId].price;
    }

    function getBoxRewardsCount(uint256 boxId) external view returns (uint256) {
        return s_boxes[boxId].rewards.length;
    }

    function getBoxReward(uint256 boxId, uint256 rewardIndex) external view returns (Reward memory) {
        return s_boxes[boxId].rewards[rewardIndex];
    }

    /* ERC1155Receiver implementation */

    function onERC1155Received(
        address, /* operator */
        address, /* from */
        uint256, /* id */
        uint256, /* value */
        bytes calldata /* data */
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address, /* operator */
        address, /* from */
        uint256[] calldata, /* ids */
        uint256[] calldata, /* values */
        bytes calldata /* data */
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function onERC721Received(
        address, address, uint256, bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId ||
               interfaceId == type(IERC721Receiver).interfaceId;
    }

    // Allow contract to receive ETH
    receive() external payable {}
}