// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Lottery is VRFConsumerBaseV2Plus {
    
    // Chainlink VRF Configuration
    address vrfCoordinator; // Sepolia
    bytes32 keyHash; // Sepolia
    uint32 callbackGasLimit;
    uint16 requestConfirmations;
    uint32 numWords = 1;
    uint256 public s_subscriptionId;
    
    uint256 public constant ENTRY_FEE = 0.01 ether;
    uint256 public constant MAX_PLAYERS = 10;
    
    address[] public players;
    uint256 public lotteryRound;
    bool public lotteryActive;
    bool public pendingWinnerSelection;
    
    mapping(address => bool) public hasEntered;
    mapping(uint256 => address) public roundWinners;
    mapping(uint256 => uint256) public roundPrizePools;
    mapping(uint256 => uint256) public requestIdToRound;
    
    // Events
    event PlayerJoined(address indexed player, uint256 round, uint256 playerCount);
    event WinnerSelected(address indexed winner, uint256 round, uint256 prizePool);
    event LotteryReset(uint256 newRound);
    event RandomnessRequested(uint256 requestId, uint256 round);

    // Errors
    error OnlyOwner();
    error LotteryNotActive();
    error WinnerSelectionInProgress();
    error InvalidRequestId();
    error PrizeTransferFailed();
    error InvalidEntryFee();
    error AlreadyEntered();
    error MaxPlayersReached();
    error NotEnoughPlayers();
    error DirectEthNotAllowed();
    
    modifier lotteryIsActive() {
        if (!lotteryActive) revert LotteryNotActive();
        _;
    }
    
    modifier notPendingSelection() {
        if (pendingWinnerSelection) revert WinnerSelectionInProgress();
        _;
    }
    
    /* Constructor */
    constructor(
        address _vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        vrfCoordinator = _vrfCoordinator;
        keyHash = gasLane;
        s_subscriptionId = uint64(subscriptionId);
        callbackGasLimit = _callbackGasLimit;
    }

    function enterLottery() external payable lotteryIsActive notPendingSelection {
        if (msg.value != ENTRY_FEE) revert InvalidEntryFee();
        if (hasEntered[msg.sender]) revert AlreadyEntered();
        if (players.length >= MAX_PLAYERS) revert MaxPlayersReached();
        
        players.push(msg.sender);
        hasEntered[msg.sender] = true;
        
        emit PlayerJoined(msg.sender, lotteryRound, players.length);
        
        // Request randomness when 10 players joined
        if (players.length == MAX_PLAYERS) {
            _requestRandomWinner();
        }
    }
    
    function _requestRandomWinner() internal {
        if (players.length != MAX_PLAYERS) revert NotEnoughPlayers();
        
        pendingWinnerSelection = true;
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: keyHash,
            subId: s_subscriptionId,
            requestConfirmations: requestConfirmations,
            callbackGasLimit: callbackGasLimit,
            numWords: numWords,
            extraArgs: VRFV2PlusClient._argsToBytes(
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false}) // Changed to false for testing
            )
        });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        requestIdToRound[requestId] = lotteryRound;
        emit RandomnessRequested(requestId, lotteryRound);
    }
    
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 round = requestIdToRound[requestId];
        if (round == 0) revert InvalidRequestId();
        
        uint256 randomIndex = randomWords[0] % players.length;
        address winner = players[randomIndex];
        uint256 prizePool = address(this).balance;
        
        // Store round data
        roundWinners[round] = winner;
        roundPrizePools[round] = prizePool;
        
        emit WinnerSelected(winner, round, prizePool);
        
        // Transfer prize to winner
        (bool success, ) = payable(winner).call{value: prizePool}("");
        if (!success) revert PrizeTransferFailed();
        
        // Reset for next round
        _resetLottery();
    }
    
    function _resetLottery() internal {
        // Clear players array
        for (uint256 i = 0; i < players.length; i++) {
            hasEntered[players[i]] = false;
        }
        delete players;
        
        // Reset state
        pendingWinnerSelection = false;
        lotteryRound++;
        
        emit LotteryReset(lotteryRound);
    }
    
    // Emergency function to manually request winner (only owner)
    function manualRequestWinner() external onlyOwner lotteryIsActive {
        if (players.length != MAX_PLAYERS) revert NotEnoughPlayers();
        if (pendingWinnerSelection) revert WinnerSelectionInProgress();
        _requestRandomWinner();
    }
    
    // Emergency function to reset lottery (only owner)
    function emergencyReset() external onlyOwner {
        pendingWinnerSelection = false;
        _resetLottery();
    }
    
    // Function to pause/unpause lottery
    function toggleLottery() external onlyOwner {
        lotteryActive = !lotteryActive;
    }
    
    // Update subscription ID (only owner)
    function updateSubscriptionId(uint64 newSubscriptionId) external onlyOwner {
        s_subscriptionId = newSubscriptionId;
    }
    
    // Update VRF configuration (only owner)
    function updateVRFConfig(
        bytes32 newKeyHash,
        uint32 newCallbackGasLimit,
        uint16 newRequestConfirmations
    ) external onlyOwner {
        keyHash = newKeyHash;
        callbackGasLimit = newCallbackGasLimit;
        requestConfirmations = newRequestConfirmations;
    }
    
    // View functions
    function getPlayers() external view returns (address[] memory) {
        return players;
    }
    
    function getPlayerCount() external view returns (uint256) {
        return players.length;
    }
    
    function getCurrentPrizePool() external view returns (uint256) {
        return address(this).balance;
    }
    
    function getRoundWinner(uint256 round) external view returns (address) {
        return roundWinners[round];
    }
    
    function getRoundPrizePool(uint256 round) external view returns (uint256) {
        return roundPrizePools[round];
    }
    
    function hasPlayerEntered(address player) external view returns (bool) {
        return hasEntered[player];
    }
    
    function getContractState() external view returns (
        uint256 currentRound,
        uint256 playerCount,
        uint256 prizePool,
        bool active,
        bool pending
    ) {
        return (
            lotteryRound,
            players.length,
            address(this).balance,
            lotteryActive,
            pendingWinnerSelection
        );
    }
    
    // Fallback function to reject direct ETH transfers
    receive() external payable {
        revert DirectEthNotAllowed();
    }
    
    fallback() external payable {
        revert DirectEthNotAllowed();
    }
}
