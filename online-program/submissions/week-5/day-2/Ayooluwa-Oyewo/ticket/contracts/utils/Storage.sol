// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

abstract contract TicketStorage {
    address public superAdmin;

    uint256 public nextEventId;
    uint256 public nextTicketTypeId;
    uint256 public nextTokenId;

    struct EventDetails {
        uint256 id;
        string title;
        string imageUrl;
        string location;
        string description;
        uint256 eventDate;
        address organizer;
        bool isActive;
    }

    struct TicketType {
        uint256 id;
        uint256 eventId;
        string name;
        uint256 price;
        uint256 totalSupply;
        uint256 minted;
        string baseURI;
    }

    struct TicketMetadata {
        uint256 eventId;
        uint256 ticketTypeId;
        bool isRedeemed;
    }

    mapping(uint256 eventId => EventDetails) public events;
    mapping(uint256 ticketTypeId => TicketType) public ticketTypes;
    mapping(uint256 eventId => uint256[]) public eventTicketTypes;
    mapping(uint256 tokenId => TicketMetadata) public tickets;
    mapping(address userAddress => uint256[]) public userTickets;
    mapping(address userAddress => bool) public admins;

}
