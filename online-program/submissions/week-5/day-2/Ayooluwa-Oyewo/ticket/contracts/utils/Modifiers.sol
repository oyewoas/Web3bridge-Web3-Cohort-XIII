// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../utils/Storage.sol";
import "../utils/Errors.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

abstract contract Modifiers is TicketStorage {
    modifier onlySuperAdmin() {
        if (msg.sender != superAdmin) revert Errors.NotSuperAdmin();
        _;
    }

    modifier onlyEventOwner(uint256 eventId) {
        if (events[eventId].organizer != msg.sender) revert Errors.NotEventOwner();
        _;
    }

    modifier onlyTicketOwner(uint256 tokenId) {
        if (ERC721(address(this)).ownerOf(tokenId) != msg.sender) revert Errors.NotTicketOwner();
        _;
    }

    modifier notRedeemed(uint256 tokenId) {
        if (tickets[tokenId].isRedeemed) revert Errors.AlreadyRedeemed();
        _;
    }

    modifier eventIsActive(uint256 eventId) {
        if (!events[eventId].isActive) revert Errors.EventNotActive();
        _;
    }

    modifier eventExists(uint256 eventId) {
        if (events[eventId].organizer == address(0)) revert Errors.InvalidInput("Event does not exist");
        _;
    }

    modifier validateEventCreation(
        string memory title,
        string memory imageUrl,
        string memory location,
        string memory description,
        uint256 eventDate
    ) {
        if (bytes(title).length == 0 || bytes(imageUrl).length == 0 || bytes(location).length == 0 || bytes(description).length == 0) {
            revert Errors.InvalidInput("Event details cannot be empty");
        }
        if (eventDate <= block.timestamp) {
            revert Errors.InvalidInput("Event date must be in the future");
        }
        _;
    }

    modifier validateTicketTypeCreation(
        uint256 eventId,
        string memory name,
        uint256 price,
        uint256 totalSupply,
        string memory baseURI
    ) {
        
        if (bytes(name).length == 0 || bytes(baseURI).length == 0) {
            revert Errors.InvalidInput("Ticket type details cannot be empty");
        }
        if (price == 0) {
            revert Errors.InvalidInput("Ticket type price must be greater than zero");
        }
        if (totalSupply == 0) {
            revert Errors.InvalidInput("Ticket type total supply must be greater than zero");
        }
        _;
    }
}
