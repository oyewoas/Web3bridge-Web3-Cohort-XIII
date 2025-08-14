// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {TokenGatedDAO} from "../contracts/TokenGatedDAO.sol";
import {RoleNFT} from "../contracts/RoleNft.sol";
import {Test} from "forge-std/Test.sol";
import {TokenGatedDAOErrors} from "../contracts/libraries/Errors.sol";
import {TokenGatedDAOEvents} from "../contracts/libraries/Events.sol";

contract TokenGatedDAOTest is Test {
    TokenGatedDAO dao;
    RoleNFT roleNFT;

    address alice = address(0x1);
    address bob = address(0x2);
    address treasuryTarget = address(0x3);
    address deployer = address(0x4);

    bytes32 constant PROPOSER_ROLE = keccak256("PROPOSER");
    bytes32 constant VOTER_ROLE = keccak256("VOTER");

    function setUp() public {
        vm.startPrank(deployer);
        roleNFT = new RoleNFT("RoleNFT", "rNFT");
        dao = new TokenGatedDAO(address(roleNFT));

        // Mint NFT to Alice from owner
        roleNFT.mint(alice);
        vm.stopPrank();

        // Now Alice can grant herself roles
        vm.startPrank(alice);
        roleNFT.grantRole(1, PROPOSER_ROLE, alice, 0, true, "");
        roleNFT.grantRole(1, VOTER_ROLE, alice, 0, true, "");
        vm.stopPrank();
    }

    function test_ProposeVoteExecute() public {
        // Fund DAO with ETH
        vm.deal(address(dao), 1 ether);

        // Alice creates proposal
        vm.startPrank(alice);
        // emit ProposalCreated event
        vm.expectEmit(true, true, true, true);
        emit TokenGatedDAOEvents.ProposalCreated(
            1,
            alice,
            "Community Event Funding",
            "Funding for community events",
            block.timestamp,
            block.timestamp + 7 days
        );
        dao.propose(
            "Community Event Funding",
            "Funding for community events",
            treasuryTarget,
            "0x", // No function call, just ETH transfer
            0.5 ether
        );

        // Advance time to start voting
        vm.warp(block.timestamp + 60);

        // Alice votes YES
        vm.expectEmit(true, true, true, true);
        emit TokenGatedDAOEvents.VoteCast(
            1,
            alice,
            true,
            dao.getVotingWeight(alice)
        );
        dao.vote(1, true);

        // Advance time to end voting
        vm.warp(block.timestamp + 9 days);

        // Execute proposal
        uint256 balanceBefore = treasuryTarget.balance;
        dao.execute(1);
        uint256 balanceAfter = treasuryTarget.balance;

        assertEq(balanceAfter - balanceBefore, 0.5 ether);
        vm.stopPrank();
    }

    function test_Propose_Revert_NoRole() public {
        // Bob tries to propose without PROPOSER_ROLE
        vm.prank(bob);
        vm.expectRevert(
            TokenGatedDAOErrors.TokenGatedDAO_NotAuthorized.selector
        );
        dao.propose(
            "Invalid Proposal",
            "This should revert",
            treasuryTarget,
            "",
            0.1 ether
        );
    }
}
