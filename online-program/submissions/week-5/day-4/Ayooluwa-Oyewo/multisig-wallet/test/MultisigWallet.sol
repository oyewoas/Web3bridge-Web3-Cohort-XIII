// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MultiSigWallet.sol";

contract MultiSigWalletTest is Test {
    MultiSigWallet public multiSigWallet;
    address public owner;
    address public ownerTwo;
    address public ownerThree;
    address public ownerFour;
    address[] public owners;
    uint256 public requiredConfirmations;


    function setUp() public {
        owner = makeAddr("owner");
        ownerTwo = makeAddr("ownerTwo");
        ownerThree = makeAddr("ownerThree");
        ownerFour = makeAddr("ownerFour");
        
        owners = [owner, ownerTwo, ownerThree];
        requiredConfirmations = 3;
        
        multiSigWallet = new MultiSigWallet(owners, requiredConfirmations);
        
        // Fund the multisig wallet and test deposit event
        vm.expectEmit(true, false, false, true);
        emit MultiSigWallet.Deposit(address(this), 5 ether, 5 ether);
        (bool success,) = address(multiSigWallet).call{value: 5 ether}("");
        require(success, "Failed to send ether");
    }

    // ============ DEPLOYMENT TESTS ============
    
    function testDeployment() public {
        assertEq(multiSigWallet.transactionCount(), 0);
        assertEq(multiSigWallet.requiredConfirmations(), requiredConfirmations);
        assertEq(multiSigWallet.getOwners().length, owners.length);
        assertTrue(multiSigWallet.isOwner(owner));
        assertTrue(multiSigWallet.isOwner(ownerTwo));
        assertTrue(multiSigWallet.isOwner(ownerThree));
        assertFalse(multiSigWallet.isOwner(makeAddr("random")));
    }

    function testRevertIfNoOwnersProvided() public {
        address[] memory emptyOwners;
        vm.expectRevert(MultiSigWallet.MultiSigWallet_OwnersRequired.selector);
        new MultiSigWallet(emptyOwners, 1);
    }

    function testRevertIfRequiredConfirmationsInvalid() public {
        address[] memory singleOwner = new address[](1);
        singleOwner[0] = owner;
        
        vm.expectRevert(MultiSigWallet.MultiSigWallet_InvalidRequiredConfirmations.selector);
        new MultiSigWallet(singleOwner, 2);
    }

    function testRevertIfDuplicateOwnersProvided() public {
        address[] memory duplicateOwners = new address[](2);
        duplicateOwners[0] = owner;
        duplicateOwners[1] = owner;
        
        vm.expectRevert(MultiSigWallet.MultiSigWallet_DuplicateOwnerAddress.selector);
        new MultiSigWallet(duplicateOwners, 2);
    }

    function testRevertIfZeroAddressProvided() public {
        address[] memory ownersWithZero = new address[](2);
        ownersWithZero[0] = owner;
        ownersWithZero[1] = address(0);
        
        vm.expectRevert(MultiSigWallet.MultiSigWallet_InvalidOwnerAddress.selector);
        new MultiSigWallet(ownersWithZero, 2);
    }

    // ============ DEPOSIT TESTS ============

    function testReceiveEther() public {
        uint256 depositAmount = 2 ether;
        uint256 initialBalance = address(multiSigWallet).balance;
        
        vm.expectEmit(true, false, false, true);
        emit MultiSigWallet.Deposit(address(this), depositAmount, initialBalance + depositAmount);
        
        (bool success,) = address(multiSigWallet).call{value: depositAmount}("");
        require(success, "Failed to send ether");
        
        assertEq(address(multiSigWallet).balance, initialBalance + depositAmount);
    }

    // ============ SUBMIT TRANSACTION TESTS ============

    function testSubmitTransaction() public {
        address destination = owner;
        uint256 value = 1 ether;
        bytes memory data = "";

        vm.prank(owner);
        // Expect TransactionSubmitted event
        vm.expectEmit(true, true, false, true);
        emit MultiSigWallet.TransactionSubmitted(0, destination, value);
        multiSigWallet.submitTransaction(destination, value, data);

        (
            address txDestination,
            uint256 txValue,
            bytes memory txData,
            bool executed,
            uint256 confirmationCount
        ) = multiSigWallet.getTransaction(0);

        assertEq(txDestination, destination);
        assertEq(txValue, value);
        assertEq(txData, data);
        assertFalse(executed);
        assertEq(confirmationCount, 0);
    }

    function testRevertSubmitTransactionIfNotOwner() public {
        vm.prank(ownerFour);
        vm.expectRevert(MultiSigWallet.MultiSigWallet_NotAnOwner.selector);
        multiSigWallet.submitTransaction(owner, 1 ether, "");
    }

    // ============ CONFIRM TRANSACTION TESTS ============

    function testConfirmTransaction() public {
        // Submit transaction first
        vm.prank(owner);
        multiSigWallet.submitTransaction(owner, 1 ether, "");

        // Confirm transaction with event expectations
        vm.prank(ownerTwo);
        vm.expectEmit(true, true, false, false);
        emit MultiSigWallet.TransactionConfirmed(0, ownerTwo);
        multiSigWallet.confirmTransaction(0);
        
        vm.prank(ownerThree);
        vm.expectEmit(true, true, false, false);
        emit MultiSigWallet.TransactionConfirmed(0, ownerThree);
        multiSigWallet.confirmTransaction(0);

        (, , , , uint256 confirmationCount) = multiSigWallet.getTransaction(0);
        assertEq(confirmationCount, 2);
    }

    function testRevertConfirmTransactionIfNotOwner() public {
        vm.prank(owner);
        multiSigWallet.submitTransaction(ownerTwo, 1 ether, "");

        vm.prank(ownerFour);
        vm.expectRevert(MultiSigWallet.MultiSigWallet_NotAnOwner.selector);
        multiSigWallet.confirmTransaction(0);
    }

    function testRevertConfirmTransactionIfDoesNotExist() public {
        vm.prank(owner);
        vm.expectRevert(MultiSigWallet.MultiSigWallet_TransactionDoesNotExist.selector);
        multiSigWallet.confirmTransaction(1);
    }

    function testRevertConfirmTransactionIfAlreadyConfirmed() public {
        vm.prank(owner);
        multiSigWallet.submitTransaction(owner, 1 ether, "");

        vm.prank(ownerTwo);
        multiSigWallet.confirmTransaction(0);

        vm.prank(ownerTwo);
        vm.expectRevert(MultiSigWallet.MultiSigWallet_TransactionAlreadyConfirmed.selector);
        multiSigWallet.confirmTransaction(0);
    }

    // ============ REVOKE CONFIRMATION TESTS ============

    function testRevokeConfirmation() public {
        // Submit and confirm transaction
        vm.prank(owner);
        multiSigWallet.submitTransaction(owner, 1 ether, "");

        vm.prank(ownerTwo);
        multiSigWallet.confirmTransaction(0);
        
        vm.prank(ownerThree);
        multiSigWallet.confirmTransaction(0);

        // Check initial confirmation count
        (, , , , uint256 initialCount) = multiSigWallet.getTransaction(0);
        assertEq(initialCount, 2);

        // Revoke confirmation with event expectation
        vm.prank(ownerTwo);
        vm.expectEmit(true, true, false, false);
        emit MultiSigWallet.TransactionRevoked(0, ownerTwo);
        multiSigWallet.revokeConfirmation(0);

        // Check updated confirmation count
        (, , , , uint256 updatedCount) = multiSigWallet.getTransaction(0);
        assertEq(updatedCount, 1);
    }

    function testRevertRevokeConfirmationIfNotOwner() public {
        vm.prank(ownerFour);
        vm.expectRevert(MultiSigWallet.MultiSigWallet_NotAnOwner.selector);
        multiSigWallet.revokeConfirmation(0);
    }

    function testRevertRevokeConfirmationIfTransactionDoesNotExist() public {
        vm.prank(owner);
        vm.expectRevert(MultiSigWallet.MultiSigWallet_TransactionDoesNotExist.selector);
        multiSigWallet.revokeConfirmation(1);
    }

    function testRevertRevokeConfirmationIfNotConfirmedByOwner() public {
        vm.prank(owner);
        multiSigWallet.submitTransaction(owner, 1 ether, "");

        vm.prank(ownerTwo);
        multiSigWallet.confirmTransaction(0);

        vm.prank(owner);
        vm.expectRevert(MultiSigWallet.MultiSigWallet_TransactionNotConfirmed.selector);
        multiSigWallet.revokeConfirmation(0);
    }

    // ============ EXECUTE TRANSACTION TESTS ============

    function testExecuteTransaction() public {
        // Submit transaction
        vm.prank(owner);
        multiSigWallet.submitTransaction(owner, 1 ether, "");

        // Get all required confirmations
        vm.prank(ownerTwo);
        multiSigWallet.confirmTransaction(0);
        
        vm.prank(ownerThree);
        multiSigWallet.confirmTransaction(0);
        
        vm.prank(owner);
        multiSigWallet.confirmTransaction(0);

        // Execute transaction as owner with event expectation
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit MultiSigWallet.TransactionExecuted(0);
        multiSigWallet.executeTransaction(0);

        (, , , bool executed, ) = multiSigWallet.getTransaction(0);
        assertTrue(executed);
    }

    function testRevertExecuteTransactionIfNotEnoughConfirmations() public {
        vm.prank(owner);
        multiSigWallet.submitTransaction(owner, 1 ether, "");

        vm.prank(owner);
        vm.expectRevert(MultiSigWallet.MultiSigWallet_NotEnoughConfirmations.selector);
        multiSigWallet.executeTransaction(0);
    }

    function testRevertExecuteTransactionIfDoesNotExist() public {
        vm.prank(owner);
        vm.expectRevert(MultiSigWallet.MultiSigWallet_TransactionDoesNotExist.selector);
        multiSigWallet.executeTransaction(1);
    }

    function testRevertExecuteTransactionIfAlreadyExecuted() public {
        // Submit and fully confirm transaction
        vm.prank(owner);
        multiSigWallet.submitTransaction(owner, 1 ether, "");

        vm.prank(ownerTwo);
        multiSigWallet.confirmTransaction(0);
        
        vm.prank(ownerThree);
        multiSigWallet.confirmTransaction(0);
        
        vm.prank(owner);
        multiSigWallet.confirmTransaction(0);

        // Execute transaction as owner
        vm.prank(owner);
        multiSigWallet.executeTransaction(0);

        // Try to execute again as owner
        vm.prank(owner);
        vm.expectRevert(MultiSigWallet.MultiSigWallet_TransactionAlreadyExecuted.selector);
        multiSigWallet.executeTransaction(0);
    }

    function testRevertExecuteTransactionIfExecutionFails() public {
        // Remove balance from multisig wallet
        vm.deal(address(multiSigWallet), 0);

        // Submit transaction for 1 ether (more than available)
        vm.prank(owner);
        multiSigWallet.submitTransaction(owner, 1 ether, "");

        // Get all required confirmations
        vm.prank(ownerTwo);
        multiSigWallet.confirmTransaction(0);
        
        vm.prank(ownerThree);
        multiSigWallet.confirmTransaction(0);
        
        vm.prank(owner);
        multiSigWallet.confirmTransaction(0);

        // Try to execute as owner (should fail due to insufficient balance)
        vm.prank(owner);
        vm.expectRevert(MultiSigWallet.MultiSigWallet_TransactionExecutionFailed.selector);
        multiSigWallet.executeTransaction(0);
    }

    // ============ GETTER TESTS ============

    function testGetOwners() public {
        address[] memory contractOwners = multiSigWallet.getOwners();
        assertEq(contractOwners.length, owners.length);
        for (uint i = 0; i < owners.length; i++) {
            assertEq(contractOwners[i], owners[i]);
        }
    }

    function testGetTransactionCount() public {
        assertEq(multiSigWallet.getTransactionCount(), 0);
        
        vm.prank(owner);
        multiSigWallet.submitTransaction(owner, 1 ether, "");
        
        assertEq(multiSigWallet.getTransactionCount(), 1);
    }

    function testGetTransaction() public {
        vm.prank(owner);
        multiSigWallet.submitTransaction(owner, 1 ether, "");

        (
            address destination,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 confirmationCount
        ) = multiSigWallet.getTransaction(0);

        assertEq(destination, owner);
        assertEq(value, 1 ether);
        assertEq(data, "");
        assertFalse(executed);
        assertEq(confirmationCount, 0);
    }
}