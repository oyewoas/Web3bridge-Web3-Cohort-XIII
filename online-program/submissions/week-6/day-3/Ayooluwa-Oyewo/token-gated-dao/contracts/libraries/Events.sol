// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library RoleNFTEvents {
    event RoleGranted(
        uint256 indexed tokenId,
        bytes32 indexed role,
        address indexed user,
        uint64 expirationDate
    );

    event RoleRevoked(
        uint256 indexed tokenId,
        bytes32 indexed role,
        address indexed user
    );


}

library TokenGatedDAOEvents{
 event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        string description,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 weight
    );

    event ProposalExecuted(uint256 indexed proposalId);

}