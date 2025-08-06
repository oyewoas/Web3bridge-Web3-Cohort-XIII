// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721URIStorage, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MyNft is ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;

    constructor() ERC721("MyNft", "MNFT") Ownable(msg.sender) {}

    // events
    event NftMinted(uint256 indexed tokenId, address indexed recipient, string tokenURI);
    event NftBurned(uint256 indexed tokenId);
    // errors
    error MyNft_NoRecipient();
    error MyNft_NoTokenURI();
    error MyNft_NotMinted();
    error MyNft_NotOwner();


    function mint(address recipient, string memory tokenURI) public returns (uint256) {
        if (recipient == address(0)) {
            revert MyNft_NoRecipient();
        }
        if (bytes(tokenURI).length == 0) {
            revert MyNft_NoTokenURI();
        }
        uint256 tokenId = _nextTokenId++;
        _mint(recipient, tokenId);
        _setTokenURI(tokenId, tokenURI);
        emit NftMinted(tokenId, recipient, tokenURI);
        return tokenId;
    }

    function burn(uint256 tokenId) public onlyOwner {
        _burn(tokenId);
        emit NftBurned(tokenId);
    }

    function getNextTokenId() external view returns (uint256) {
        return _nextTokenId;
    }
}