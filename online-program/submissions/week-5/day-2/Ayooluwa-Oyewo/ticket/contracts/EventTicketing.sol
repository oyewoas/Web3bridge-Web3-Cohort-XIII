// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./utils/Storage.sol";
import "./utils/Modifiers.sol";
import "./utils/Errors.sol";
import "./utils/Events.sol";

contract EventTicketing is TicketStorage, Modifiers, ERC721URIStorage {
    using Errors for *;
    using TicketEvents for *;

    constructor() ERC721("EventTicket", "ETKT") {
        superAdmin = msg.sender;
    }

    function addAdmin(address admin) external onlySuperAdmin {
        admins[admin] = true;
        emit TicketEvents.AdminAdded(admin);
    }
    function removeAdmin(address admin) external onlySuperAdmin {
        admins[admin] = false;
        emit TicketEvents.AdminRemoved(admin);
    }


    function createEvent(
        string memory title,
        string memory imageUrl,
        string memory location,
        string memory description,
        uint256 eventDate
    ) external validateEventCreation(title, imageUrl, location, description, eventDate) returns (uint256) {
        uint256 id = nextEventId++;
        events[id] = EventDetails(id, title, imageUrl, location, description, eventDate, msg.sender, true);
        emit TicketEvents.EventCreated(id, title);
        return id;
    }

    function updateEvent(
        uint256 eventId,
        string memory title,
        string memory imageUrl,
        string memory location,
        string memory description,
        uint256 eventDate
    ) external eventExists(eventId) onlyEventOwner(eventId) validateEventCreation(title, imageUrl, location, description, eventDate) {
        EventDetails storage eventDetails = events[eventId];
        eventDetails.title = title;
        eventDetails.imageUrl = imageUrl;
        eventDetails.location = location;
        eventDetails.description = description;
        eventDetails.eventDate = eventDate;
        emit TicketEvents.EventUpdated(eventId, title);
    }

    function modifyEventStatus(uint256 eventId, bool isActive) external eventExists(eventId) onlyEventOwner(eventId) {
        events[eventId].isActive = isActive;
        emit TicketEvents.EventStatusModified(eventId, isActive);
    }

    function createTicketType(
        uint256 eventId,
        string memory name,
        uint256 price,
        uint256 totalSupply,
        string memory baseURI
    ) external eventExists(eventId) onlyEventOwner(eventId) validateTicketTypeCreation(eventId,name, price, totalSupply, baseURI) {
        uint256 id = nextTicketTypeId++;
        ticketTypes[id] = TicketType(id, eventId, name, price, totalSupply, 0, baseURI);
        eventTicketTypes[eventId].push(id);
        emit TicketEvents.TicketTypeCreated(id, eventId, name);
    }

    function mintTicket(uint256 ticketTypeId)
        external
        payable
        eventExists(ticketTypes[ticketTypeId].eventId)
        eventIsActive(ticketTypes[ticketTypeId].eventId)
    {
        TicketType storage tt = ticketTypes[ticketTypeId];
        if (tt.minted >= tt.totalSupply) revert Errors.SoldOut();
        if (msg.value < tt.price) revert Errors.InvalidPayment();

        uint256 tokenId = nextTokenId++;
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, tt.baseURI);

        tickets[tokenId] = TicketMetadata(tt.eventId, ticketTypeId, false);
        userTickets[msg.sender].push(tokenId);
        tt.minted++;

        emit TicketEvents.TicketMinted(tokenId, msg.sender);
    }

    function redeemTicket(uint256 tokenId)
        external
        eventExists(tickets[tokenId].eventId)
        onlyTicketOwner(tokenId)
        notRedeemed(tokenId)
    {
        tickets[tokenId].isRedeemed = true;
        emit TicketEvents.TicketRedeemed(tokenId, msg.sender);
    }
}
