// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {RoleNFT} from "../contracts/RoleNft.sol";
import {Test} from "forge-std/Test.sol";
import {IERC7432} from "../contracts/interfaces/IERC7432.sol";
import {RoleNFTEvents} from "../contracts/libraries/Events.sol";
import {RoleNFTErrors} from "../contracts/libraries/Errors.sol";

contract RoleNFTTest is Test {
    RoleNFT roleNFT;
    address deployer = address(0xDEAD);

    address alice = address(0x1);
    address bob = address(0x2);

    bytes32 constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    function setUp() public {
        vm.prank(deployer);
        roleNFT = new RoleNFT("RoleNFT", "rNFT");
    }

    function test_InitialValue() public view {
        assertEq(roleNFT.totalSupply(), 0);
    }

    function test_Mint() public {
        vm.prank(deployer);
        roleNFT.mint(alice);
        assertEq(roleNFT.totalSupply(), 1);
        assertEq(roleNFT.ownerOf(1), alice);
    }

    function test_GrantRole_Success() public {
        vm.startPrank(deployer);
        // Mint to Alice
        roleNFT.mint(alice);
        vm.stopPrank();
        uint256 tokenId = 1;

        // Alice grants ADMIN_ROLE to Bob
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit RoleNFTEvents.RoleGranted(tokenId, ADMIN_ROLE, bob, 0);
        roleNFT.grantRole(tokenId, ADMIN_ROLE, bob, 0, true, "");

        // Check that Bob has the role
        IERC7432.RoleData memory roleData = roleNFT.roleData(
            tokenId,
            ADMIN_ROLE,
            bob
        );
        assertEq(roleData.expirationDate, 0);
        assertTrue(roleData.revocable);
        assertEq(roleData.data.length, 0);
    }

    function test_GrantRole_Revert_NotOwnerOrApproved() public {
        vm.startPrank(deployer);
        roleNFT.mint(alice);
        vm.stopPrank();
        uint256 tokenId = 1;
        
        vm.prank(bob);

        // Bob tries granting without approval
        vm.expectRevert(
            abi.encodeWithSelector(
                RoleNFTErrors.RoleNFT_NotAuthorized.selector,
                tokenId,
                ADMIN_ROLE,
                bob
            )
        );
        roleNFT.grantRole(tokenId, ADMIN_ROLE, bob, 0, true, "");
    }

    function test_GrantRole_Revert_Expired() public {
        vm.warp(1000);
        vm.prank(deployer);
        roleNFT.mint(alice);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                RoleNFTErrors.RoleNFT_InvalidExpiration.selector,
                1,
                keccak256("TEST_ROLE"),
                alice
            )
        );
        uint256 pastTime = block.timestamp - 100;

        roleNFT.grantRole(
            1,
            keccak256("TEST_ROLE"),
            alice,
            uint64(pastTime), // Already expired
            true,
            ""
        );
    }

    function test_GrantRole_Revert_TokenDoesNotExist() public {
        vm.startPrank(deployer);
        roleNFT.mint(alice);
        vm.stopPrank();

        // Try to grant a role on a non-existent token
        vm.expectRevert(
            abi.encodeWithSelector(
                RoleNFTErrors.RoleNFT_TokenDoesNotExist.selector,
                2
            )
        );
        vm.prank(alice);
        roleNFT.grantRole(2, ADMIN_ROLE, bob, 0, true, "");
    }

    function test_RevokeRole_Revert_NotOwnerOrApproved() public {
        vm.startPrank(deployer);
        roleNFT.mint(alice);
        vm.stopPrank();
        uint256 tokenId = 1;

        // grant role first
        vm.startPrank(alice);
        roleNFT.grantRole(tokenId, ADMIN_ROLE, bob, 0, true, "");
        vm.stopPrank();
        vm.prank(bob);

        // Bob tries revoking without approval
        vm.expectRevert(
            abi.encodeWithSelector(
                RoleNFTErrors.RoleNFT_NotAuthorized.selector,
                tokenId,
                ADMIN_ROLE,
                bob
            )
        );
        roleNFT.revokeRole(tokenId, ADMIN_ROLE, bob);
    }

    function test_RevokeRole_RoleNotGranted() public {
        vm.startPrank(deployer);
        roleNFT.mint(alice);
        vm.stopPrank();
        uint256 tokenId = 1;

        // Bob tries revoking a role that was not granted
        vm.expectRevert(
            abi.encodeWithSelector(
                RoleNFTErrors.RoleNFT_RoleNotGranted.selector,
                tokenId,
                ADMIN_ROLE,
                bob
            )
        );
        vm.prank(bob);
        roleNFT.revokeRole(tokenId, ADMIN_ROLE, bob);
    }

    function test_RevokeRole_RoleNotRevocable() public {
        vm.startPrank(deployer);
        roleNFT.mint(alice);
        vm.stopPrank();
        uint256 tokenId = 1;

        vm.startPrank(alice);
        roleNFT.grantRole(tokenId, ADMIN_ROLE, bob, 0, false, "");
        vm.stopPrank();

        // Bob tries revoking a role that is not revocable
        vm.expectRevert(
            abi.encodeWithSelector(
                RoleNFTErrors.RoleNFT_RoleNotRevocable.selector,
                tokenId,
                ADMIN_ROLE,
                bob
            )
        );
        vm.prank(bob);
        roleNFT.revokeRole(tokenId, ADMIN_ROLE, bob);
    }

    function test_Burn() public {
        vm.startPrank(deployer);
        roleNFT.mint(alice);
        assertEq(roleNFT.totalSupply(), 1);
        roleNFT.burn(1); // only contract owner allowed
        vm.stopPrank();

        assertEq(roleNFT.totalSupply(), 0);

        vm.expectRevert(); // token no longer exists
        roleNFT.ownerOf(1);
    }
}
