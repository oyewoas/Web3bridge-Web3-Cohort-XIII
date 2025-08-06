// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library Errors {
    error SoldOut();
    error InvalidPayment();
    error NotEventOwner();
    error NotTicketOwner();
    error AlreadyRedeemed();
    error EventNotActive();
    error NotSuperAdmin();
    error InvalidInput(string reason);
}
