// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library RoleNFTErrors {
   error RoleNFT_RoleNotGranted(uint256 tokenId, bytes32 role, address user);
    error RoleNFT_RoleNotRevocable(uint256 tokenId, bytes32 role, address user);
    error RoleNFT_NotAuthorized(uint256 tokenId, bytes32 role, address user);
    error RoleNFT_InvalidExpiration(uint256 tokenId, bytes32 role, address user);
    error RoleNFT_TokenDoesNotExist(uint256 tokenId);
    error RoleNFT_RoleAlreadyGranted(uint256 tokenId, bytes32 role, address user);
}

library TokenGatedDAOErrors {
  error TokenGatedDAO_NotAuthorized();
    error TokenGatedDAO_ProposalNotActive();
    error TokenGatedDAO_VotingNotStarted();
    error TokenGatedDAO_VotingEnded();
    error TokenGatedDAO_AlreadyVoted();
    error TokenGatedDAO_InvalidProposalId();
    error TokenGatedDAO_AlreadyExecuted();
    error TokenGatedDAO_VotingStillActive();
}