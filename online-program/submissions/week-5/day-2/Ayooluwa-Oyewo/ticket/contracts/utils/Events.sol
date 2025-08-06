// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library TicketEvents {
    event EventCreated(uint256 indexed eventId, string title);
    event TicketTypeCreated(uint256 indexed ticketTypeId, uint256 indexed eventId, string name);
    event TicketMinted(uint256 indexed tokenId, address indexed to);
    event TicketRedeemed(uint256 indexed tokenId, address indexed user);
    event EventStatusModified(uint256 indexed eventId, bool isActive);
    event EventUpdated(uint256 indexed eventId, string title);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
}
