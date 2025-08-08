// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract RewardNFT is ERC721 {
    using Strings for uint256;

    uint256 private _nextTokenId;

    // Store metadata components separately for better storage handling
    struct TokenMetadata {
        string name;
        string description;
        string image;
    }

    // Mappings for metadata storage
    mapping(uint256 => TokenMetadata) private _tokenMetadata;
    mapping(uint256 => string[]) private _tokenAttributes;
    mapping(uint256 => string[]) private _tokenValues;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    // Events
    event NftMinted(uint256 indexed tokenId, address indexed recipient, string name);
    event NftBurned(uint256 indexed tokenId);

    // Errors
    error MyOnChainNft_NoRecipient();
    error MyOnChainNft_NoName();
    error MyOnChainNft_AttributesMismatch();
    error MyOnChainNft_NotMinted();

    /**
     * @dev Mint an NFT with on-chain metadata
     * @param recipient Address to receive the NFT
     * @param name Name of the NFT
     * @param description Description of the NFT
     * @param image Image data (SVG, base64, or IPFS hash)
     * @param attributes Array of attribute names
     * @param values Array of attribute values (must match attributes length)
     */
    function mint(
        address recipient,
        string memory name,
        string memory description,
        string memory image,
        string[] memory attributes,
        string[] memory values
    ) public returns (uint256) {
        if (recipient == address(0)) {
            revert MyOnChainNft_NoRecipient();
        }
        if (bytes(name).length == 0) {
            revert MyOnChainNft_NoName();
        }
        if (attributes.length != values.length) {
            revert MyOnChainNft_AttributesMismatch();
        }

        uint256 tokenId = _nextTokenId++;
        
        // Store basic metadata
        _tokenMetadata[tokenId] = TokenMetadata({
            name: name,
            description: description,
            image: image
        });

        // Store attributes and values arrays
        for (uint256 i = 0; i < attributes.length; i++) {
            _tokenAttributes[tokenId].push(attributes[i]);
            _tokenValues[tokenId].push(values[i]);
        }

        _mint(recipient, tokenId);
        emit NftMinted(tokenId, recipient, name);
        return tokenId;
    }

    /**
     * @dev Mint an NFT with simple metadata (name and description only)
     */
    function mintSimple(
        address recipient,
        string memory name,
        string memory description,
        string memory image
    ) public returns (uint256) {
        string[] memory emptyAttributes = new string[](0);
        string[] memory emptyValues = new string[](0);
        
        return mint(recipient, name, description, image, emptyAttributes, emptyValues);
    }

    /**
     * @dev Generate SVG image on-chain (example implementation)
     */
    function generateSVG(uint256 tokenId, string memory color) public pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" viewBox="0 0 200 200">',
                '<rect width="200" height="200" fill="', color, '"/>',
                '<text x="100" y="100" text-anchor="middle" fill="white" font-size="20" font-family="Arial">',
                'Token #', tokenId.toString(),
                '</text>',
                '</svg>'
            )
        );
    }

    /**
     * @dev Generate a complete SVG data URI
     */
    function generateSVGDataURI(uint256 tokenId, string memory color) public pure returns (string memory) {
        string memory svg = generateSVG(tokenId, color);
        return string(
            abi.encodePacked(
                "data:image/svg+xml;base64,",
                Base64.encode(bytes(svg))
            )
        );
    }

    /**
     * @dev Mint with auto-generated SVG image
     */
    function mintWithGeneratedImage(
        address recipient,
        string memory name,
        string memory description,
        string memory color,
        string[] memory attributes,
        string[] memory values
    ) public returns (uint256) {
        uint256 tokenId = _nextTokenId;
        string memory imageDataURI = generateSVGDataURI(tokenId, color);
        
        return mint(recipient, name, description, imageDataURI, attributes, values);
    }

    /**
     * @dev Returns the token URI with JSON metadata encoded in base64
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (!_exists(tokenId)) {
            revert MyOnChainNft_NotMinted();
        }

        TokenMetadata memory metadata = _tokenMetadata[tokenId];
        string[] memory attributes = _tokenAttributes[tokenId];
        string[] memory values = _tokenValues[tokenId];
        
        // Build attributes JSON array
        string memory attributesJson = "";
        if (attributes.length > 0) {
            attributesJson = '"attributes": [';
            for (uint256 i = 0; i < attributes.length; i++) {
                attributesJson = string(
                    abi.encodePacked(
                        attributesJson,
                        '{"trait_type": "', attributes[i], '", "value": "', values[i], '"}',
                        i < attributes.length - 1 ? "," : ""
                    )
                );
            }
            attributesJson = string(abi.encodePacked(attributesJson, "],"));
        }

        // Build complete JSON metadata
        string memory json = string(
            abi.encodePacked(
                '{',
                '"name": "', metadata.name, '",',
                '"description": "', metadata.description, '",',
                '"image": "', metadata.image, '",',
                attributesJson,
                '"tokenId": ', tokenId.toString(),
                '}'
            )
        );

        // Encode JSON in base64 and return as data URI
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(bytes(json))
            )
        );
    }

    /**
     * @dev Get metadata for a token
     */
    function getTokenMetadata(uint256 tokenId) external view returns (
        string memory name,
        string memory description,
        string memory image,
        string[] memory attributes,
        string[] memory values
    ) {
        if (!_exists(tokenId)) {
            revert MyOnChainNft_NotMinted();
        }
        
        TokenMetadata memory metadata = _tokenMetadata[tokenId];
        return (
            metadata.name,
            metadata.description,
            metadata.image,
            _tokenAttributes[tokenId],
            _tokenValues[tokenId]
        );
    }

    /**
     * @dev Update metadata for a token (only owner)
     */
    function updateTokenMetadata(
        uint256 tokenId,
        string memory name,
        string memory description,
        string memory image,
        string[] memory attributes,
        string[] memory values
    ) external {
        if (!_exists(tokenId)) {
            revert MyOnChainNft_NotMinted();
        }
        if (attributes.length != values.length) {
            revert MyOnChainNft_AttributesMismatch();
        }

        // Update basic metadata
        _tokenMetadata[tokenId] = TokenMetadata({
            name: name,
            description: description,
            image: image
        });

        // Clear and update attributes/values
        delete _tokenAttributes[tokenId];
        delete _tokenValues[tokenId];
        
        for (uint256 i = 0; i < attributes.length; i++) {
            _tokenAttributes[tokenId].push(attributes[i]);
            _tokenValues[tokenId].push(values[i]);
        }
    }

    /**
     * @dev Burn an NFT
     */
    function burn(uint256 tokenId) public {
        _burn(tokenId);
        delete _tokenMetadata[tokenId];
        delete _tokenAttributes[tokenId];
        delete _tokenValues[tokenId];
        emit NftBurned(tokenId);
    }

    /**
     * @dev Get the next token ID
     */
    function getNextTokenId() external view returns (uint256) {
        return _nextTokenId;
    }

    /**
     * @dev Check if a token exists
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
}