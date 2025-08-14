// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IERC7432.sol";
import "./RoleNft.sol";
import {TokenGatedDAOErrors} from "./libraries/Errors.sol";
import {TokenGatedDAOEvents} from "./libraries/Events.sol";
/**
 * @title TokenGatedDAO
 * @dev DAO contract with role-based governance using ERC-7432
 */
contract TokenGatedDAO {
    // Role definitions
    bytes32 public constant VOTER_ROLE = keccak256("VOTER");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");

    enum ProposalState {
        Pending,
        Active,
        Succeeded,
        Defeated,
        Executed
    }

    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        address target;
        bytes callData;
        uint256 value;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        ProposalState state;
    }

    RoleNFT public immutable roleNFT;
    uint256 public proposalCount;
    uint256 public constant VOTING_DURATION = 7 days;
    uint256 public constant PROPOSAL_THRESHOLD = 1; // Minimum tokens with PROPOSER role needed

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    constructor(address _roleNFT) {
        roleNFT = RoleNFT(_roleNFT);
    }

    /**
     * @notice Creates a new proposal
     * @param title The proposal title
     * @param description The proposal description
     * @param target The target contract address for execution
     * @param callData The call data for execution
     * @param value The ETH value to send with the call
     */
    function propose(
        string memory title,
        string memory description,
        address target,
        bytes memory callData,
        uint256 value
    ) external returns (uint256) {
        if (!hasProposerRole(msg.sender))
            revert TokenGatedDAOErrors.TokenGatedDAO_NotAuthorized();

        uint256 proposalId = ++proposalCount;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + VOTING_DURATION;

        Proposal storage p = proposals[proposalId];
        p.id = proposalId;
        p.proposer = msg.sender;
        p.title = title;
        p.description = description;
        p.target = target;
        p.callData = callData;
        p.value = value;
        p.startTime = startTime;
        p.endTime = endTime;
        p.executed = false;
        p.state = ProposalState.Active;

        emit TokenGatedDAOEvents.ProposalCreated(
            proposalId,
            msg.sender,
            title,
            description,
            startTime,
            endTime
        );

        return proposalId;
    }

    /**
     * @notice Casts a vote on a proposal
     * @param proposalId The proposal ID
     * @param support True for yes, false for no
     */
    function vote(uint256 proposalId, bool support) external {
        if (!hasVoterRole(msg.sender))
            revert TokenGatedDAOErrors.TokenGatedDAO_NotAuthorized();
        if (proposalId > proposalCount || proposalId == 0)
            revert TokenGatedDAOErrors.TokenGatedDAO_InvalidProposalId();

        if (hasVoted[proposalId][msg.sender])
            revert TokenGatedDAOErrors.TokenGatedDAO_AlreadyVoted();

        Proposal storage proposal = proposals[proposalId];
        if (proposal.state != ProposalState.Active)
            revert TokenGatedDAOErrors.TokenGatedDAO_ProposalNotActive();
        if (block.timestamp < proposal.startTime)
            revert TokenGatedDAOErrors.TokenGatedDAO_VotingNotStarted();
        if (block.timestamp > proposal.endTime)
            revert TokenGatedDAOErrors.TokenGatedDAO_VotingEnded();

        hasVoted[proposalId][msg.sender] = true;
        uint256 weight = getVotingWeight(msg.sender);

        if (support) {
            proposal.votesFor += weight;
        } else {
            proposal.votesAgainst += weight;
        }

        emit TokenGatedDAOEvents.VoteCast(
            proposalId,
            msg.sender,
            support,
            weight
        );
    }

    /**
     * @notice Executes a successful proposal
     * @param proposalId The proposal ID
     */
    function execute(uint256 proposalId) external payable {
        if (proposalId > proposalCount || proposalId == 0)
            revert TokenGatedDAOErrors.TokenGatedDAO_InvalidProposalId();

        Proposal storage proposal = proposals[proposalId];
        if (proposal.state != ProposalState.Active)
            revert TokenGatedDAOErrors.TokenGatedDAO_ProposalNotActive();
        if (block.timestamp <= proposal.endTime)
            revert TokenGatedDAOErrors.TokenGatedDAO_VotingStillActive();
        if (proposal.executed)
            revert TokenGatedDAOErrors.TokenGatedDAO_AlreadyExecuted();

        // Update proposal state based on voting results
        if (proposal.votesFor > proposal.votesAgainst) {
            proposal.state = ProposalState.Succeeded;
        } else {
            proposal.state = ProposalState.Defeated;
            return;
        }

        proposal.executed = true;
        proposal.state = ProposalState.Executed;

        // Execute the proposal
        if (proposal.target != address(0) && proposal.callData.length > 0) {
            (bool success, ) = proposal.target.call{value: proposal.value}(
                proposal.callData
            );
            require(success, "Proposal execution failed");
        }

        emit TokenGatedDAOEvents.ProposalExecuted(proposalId);
    }

    /**
     * @notice Gets the current state of a proposal
     */
    function getProposalState(
        uint256 proposalId
    ) external view returns (ProposalState) {
        if (proposalId > proposalCount || proposalId == 0)
            revert TokenGatedDAOErrors.TokenGatedDAO_InvalidProposalId();

        Proposal memory proposal = proposals[proposalId];

        if (proposal.executed) {
            return ProposalState.Executed;
        }

        if (block.timestamp <= proposal.endTime) {
            return ProposalState.Active;
        }

        if (proposal.votesFor > proposal.votesAgainst) {
            return ProposalState.Succeeded;
        }

        return ProposalState.Defeated;
    }

    /**
     * @notice Checks if an address has the voter role on any NFT
     */
    function hasVoterRole(address user) public view returns (bool) {
        return hasAnyRole(user, VOTER_ROLE);
    }

    /**
     * @notice Checks if an address has the proposer role on any NFT
     */
    function hasProposerRole(address user) public view returns (bool) {
        return hasAnyRole(user, PROPOSER_ROLE);
    }

    /**
     * @notice Checks if an address has the admin role on any NFT
     */
    function hasAdminRole(address user) public view returns (bool) {
        return hasAnyRole(user, ADMIN_ROLE);
    }

    /**
     * @notice Checks if a user has a specific role on any NFT
     */
    function hasAnyRole(address user, bytes32 role) public view returns (bool) {
        uint256 totalSupply = roleNFT.totalSupply();

        for (uint256 tokenId = 1; tokenId <= totalSupply; tokenId++) {
            if (roleNFT.hasRole(tokenId, role, user)) {
                return true;
            }
        }

        return false;
    }

    /**
     * @notice Gets the voting weight of a user based on their roles
     */
    function getVotingWeight(address user) public view returns (uint256) {
        uint256 totalSupply = roleNFT.totalSupply();
        uint256 weight = 0;

        for (uint256 tokenId = 1; tokenId <= totalSupply; tokenId++) {
            if (roleNFT.hasRole(tokenId, VOTER_ROLE, user)) {
                weight += 1;
            }
            // Admin role has higher voting weight
            if (roleNFT.hasRole(tokenId, ADMIN_ROLE, user)) {
                weight += 2;
            }
        }

        return weight > 0 ? weight : 0;
    }

    /**
     * @notice Allows the contract to receive ETH
     */
    receive() external payable {}

    /**
     * @notice Gets the contract's ETH balance
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
