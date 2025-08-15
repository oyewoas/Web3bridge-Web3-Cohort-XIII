/**
Task — SVG NFT that displays the current time using block.timestamp
Objective
Mint an on-chain, fully self-contained SVG NFT whose image dynamically renders the current time (derived from block.timestamp) whenever tokenURI() is queried.

 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract SvgNft is ERC721, Ownable {
    using Strings for uint256;

    uint256 private _nextTokenId;

    // Store metadata components (no longer storing static image)
    struct TokenMetadata {
        string name;
        string description;
        string backgroundColor; // For customizing the time display
        string textColor;
    }

    // Mappings for metadata storage
    mapping(uint256 => TokenMetadata) private _tokenMetadata;
    mapping(uint256 => string[]) private _tokenAttributes;
    mapping(uint256 => string[]) private _tokenValues;

    constructor() ERC721("DynamicTimeNFT", "DTNFT") Ownable(msg.sender) {}

    // Events
    event NftMinted(uint256 indexed tokenId, address indexed recipient, string name);
    event NftBurned(uint256 indexed tokenId);

    // Errors
    error SvgNft_NoRecipient();
    error SvgNft_NoName();
    error SvgNft_AttributesMismatch();
    error SvgNft_NotMinted();

    /**
     * @dev Convert timestamp to time components
     * @param timestamp Unix timestamp
     * @return hrs, mins, secs
     */
    function timestampToTime(uint256 timestamp) public pure returns (uint256, uint256, uint256) {
        // Convert to secs since midnight UTC
        uint256 secondsInDay = timestamp % 86400; // 86400 secs in a day
        
        uint256 hrs = secondsInDay / 3600;
        uint256 mins = (secondsInDay % 3600) / 60;
        uint256 secs = secondsInDay % 60;
        
        return (hrs, mins, secs);
    }

    /**
     * @dev Convert timestamp to date components
     * @param timestamp Unix timestamp  
     * @return year, month, day
     */
    function timestampToDate(uint256 timestamp) public pure returns (uint256, uint256, uint256) {
        // Simple date calculation (this is a simplified version)
        uint256 daysSinceEpoch = timestamp / 86400;
        
        // Start from 1970
        uint256 year = 1970;
        
        // Add years (accounting for leap years)
        while (true) {
            uint256 daysInYear = isLeapYear(year) ? 366 : 365;
            if (daysSinceEpoch >= daysInYear) {
                daysSinceEpoch -= daysInYear;
                year++;
            } else {
                break;
            }
        }
        
        // Add months
        uint256 month = 1;
        uint256[12] memory daysInMonth = [uint256(31), uint256(28), uint256(31), uint256(30), uint256(31), uint256(30), uint256(31), uint256(31), uint256(30), uint256(31), uint256(30), uint256(31)];
        if (isLeapYear(year)) {
            daysInMonth[1] = 29;
        }
        
        for (uint256 i = 0; i < 12; i++) {
            if (daysSinceEpoch >= daysInMonth[i]) {
                daysSinceEpoch -= daysInMonth[i];
                month++;
            } else {
                break;
            }
        }
        
        uint256 day = daysSinceEpoch + 1;
        
        return (year, month, day);
    }

    /**
     * @dev Check if year is leap year
     */
    function isLeapYear(uint256 year) internal pure returns (bool) {
        if (year % 4 != 0) return false;
        if (year % 100 != 0) return true;
        if (year % 400 != 0) return false;
        return true;
    }

    /**
     * @dev Format time as HH:MM:SS string
     */
    function formatTime(uint256 hrs, uint256 mins, uint256 secs) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                padZero(hrs), ":",
                padZero(mins), ":",
                padZero(secs)
            )
        );
    }

    /**
     * @dev Format date as YYYY-MM-DD string
     */
    function formatDate(uint256 year, uint256 month, uint256 day) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                year.toString(), "-",
                padZero(month), "-",
                padZero(day)
            )
        );
    }

    /**
     * @dev Add leading zero to single digit numbers
     */
    function padZero(uint256 value) internal pure returns (string memory) {
        if (value < 10) {
            return string(abi.encodePacked("0", value.toString()));
        }
        return value.toString();
    }

    /**
     * @dev Generate dynamic SVG image showing current time
     */
    function generateTimeSVG(uint256 tokenId) public view returns (string memory) {
        if (!_exists(tokenId)) {
            revert SvgNft_NotMinted();
        }

        TokenMetadata memory metadata = _tokenMetadata[tokenId];
        
        // Get current time from block.timestamp
        (uint256 hrs, uint256 mins, uint256 secs) = timestampToTime(block.timestamp);
        (uint256 year, uint256 month, uint256 day) = timestampToDate(block.timestamp);
        
        string memory timeString = formatTime(hrs, mins, secs);
        string memory dateString = formatDate(year, month, day);
        
        return _buildSVG(metadata, timeString, dateString, tokenId);
    }

    /**
     * @dev Internal function to build SVG string (reduces stack depth)
     */
    function _buildSVG(
        TokenMetadata memory metadata,
        string memory timeString,
        string memory dateString,
        uint256 tokenId
    ) internal view returns (string memory) {
        string memory bgColor = metadata.backgroundColor;
        string memory txtColor = metadata.textColor;
        string memory adjustedColor = adjustColor(bgColor);
        string memory blockTimestamp = block.timestamp.toString();
        string memory tokenIdString = tokenId.toString();
        
        return string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400" viewBox="0 0 400 400">',
                '<defs>',
                '<linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">',
                '<stop offset="0%" style="stop-color:', bgColor, ';stop-opacity:1" />',
                '<stop offset="100%" style="stop-color:', adjustedColor, ';stop-opacity:1" />',
                '</linearGradient>',
                '</defs>',
                _buildSVGBody(metadata.name, txtColor, timeString, dateString, blockTimestamp, tokenIdString)
            )
        );
    }

    /**
     * @dev Build SVG body elements
     */
    function _buildSVGBody(
        string memory name,
        string memory txtColor,
        string memory timeString,
        string memory dateString,
        string memory blockTimestamp,
        string memory tokenIdString
    ) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<rect width="400" height="400" fill="url(#bg)"/>',
                '<rect x="20" y="20" width="360" height="360" fill="none" stroke="', txtColor, '" stroke-width="2" rx="20"/>',
                '<text x="200" y="80" text-anchor="middle" fill="', txtColor, '" font-size="24" font-family="Arial, sans-serif" font-weight="bold">',
                name,
                '</text>',
                '<text x="200" y="180" text-anchor="middle" fill="', txtColor, '" font-size="48" font-family="monospace, Arial" font-weight="bold">',
                timeString,
                '</text>',
                '<text x="200" y="220" text-anchor="middle" fill="', txtColor, '" font-size="20" font-family="Arial, sans-serif">',
                dateString,
                '</text>',
                '<text x="200" y="280" text-anchor="middle" fill="', txtColor, '" font-size="14" font-family="monospace" opacity="0.7">',
                'Block: ', blockTimestamp,
                '</text>',
                '<text x="200" y="340" text-anchor="middle" fill="', txtColor, '" font-size="16" font-family="Arial, sans-serif" opacity="0.8">',
                'Token #', tokenIdString,
                '</text>',
                '</svg>'
            )
        );
    }

    /**
     * @dev Adjust color for gradient effect (simple brightness adjustment)
     */
    function adjustColor(string memory color) internal pure returns (string memory) {
        // For simplicity, return a slightly different color
        // In a real implementation, you could parse hex colors and adjust brightness
        if (keccak256(bytes(color)) == keccak256(bytes("#1a1a2e"))) return "#16213e";
        if (keccak256(bytes(color)) == keccak256(bytes("#0f3460"))) return "#1e5086";
        if (keccak256(bytes(color)) == keccak256(bytes("#e94560"))) return "#f56476";
        return "#2a2a5e"; // default adjustment
    }

    /**
     * @dev Generate a complete SVG data URI with current time
     */
    function generateTimeSVGDataURI(uint256 tokenId) public view returns (string memory) {
        string memory svg = generateTimeSVG(tokenId);
        return string(
            abi.encodePacked(
                "data:image/svg+xml;base64,",
                Base64.encode(bytes(svg))
            )
        );
    }

    /**
     * @dev Mint a dynamic time NFT
     * @param recipient Address to receive the NFT
     * @param name Name of the NFT  
     * @param description Description of the NFT
     * @param backgroundColor Background color for the SVG (hex color)
     * @param textColor Text color for the SVG (hex color)
     * @param attributes Array of attribute names
     * @param values Array of attribute values
     */
    function mint(
        address recipient,
        string memory name,
        string memory description,
        string memory backgroundColor,
        string memory textColor,
        string[] memory attributes,
        string[] memory values
    ) public onlyOwner returns (uint256) {
        if (recipient == address(0)) {
            revert SvgNft_NoRecipient();
        }
        if (bytes(name).length == 0) {
            revert SvgNft_NoName();
        }
        if (attributes.length != values.length) {
            revert SvgNft_AttributesMismatch();
        }

        uint256 tokenId = _nextTokenId++;
        
        // Store basic metadata (no static image!)
        _tokenMetadata[tokenId] = TokenMetadata({
            name: name,
            description: description,
            backgroundColor: bytes(backgroundColor).length > 0 ? backgroundColor : "#1a1a2e",
            textColor: bytes(textColor).length > 0 ? textColor : "#ffffff"
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
     * @dev Mint a simple dynamic time NFT with default colors
     */
    function mintSimple(
        address recipient,
        string memory name,
        string memory description
    ) public onlyOwner returns (uint256) {
        string[] memory emptyAttributes = new string[](0);
        string[] memory emptyValues = new string[](0);
        
        return mint(recipient, name, description, "#1a1a2e", "#ffffff", emptyAttributes, emptyValues);
    }

/**
 * @notice Returns the token URI containing dynamic SVG image and metadata for the given tokenId.
 * @dev This function dynamically generates metadata including:
 *      - Name and description
 *      - SVG image that shows current blockchain time
 *      - Current time/date values
 *      - Additional stored attributes
 *      - Token ID
 * @param tokenId The ID of the token to get the metadata for.
 * @return A base64-encoded JSON metadata URI string.
 */
function tokenURI(uint256 tokenId) public view override returns (string memory) {
    if (!_exists(tokenId)) {
        revert SvgNft_NotMinted();
    }

    string memory json = _buildTokenMetadataJSON(tokenId);

    // Encode JSON into a data URI
    return string(
        abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(bytes(json))
        )
    );
}

/**
 * @notice Builds the complete JSON metadata for the token.
 * @param tokenId The ID of the token.
 * @return JSON metadata string.
 */
function _buildTokenMetadataJSON(uint256 tokenId) internal view returns (string memory) {
    TokenMetadata memory metadata = _tokenMetadata[tokenId];
    string memory dynamicImageDataURI = generateTimeSVGDataURI(tokenId);

    return string(
        abi.encodePacked(
            '{',
            '"name": "', metadata.name, '",',
            '"description": "', metadata.description, ' - This NFT displays the current blockchain time dynamically.",',
            '"image": "', dynamicImageDataURI, '",',
            _buildTimeJSON(),
            _buildAttributesJSON(tokenId),
            '"tokenId": ', tokenId.toString(),
            '}'
        )
    );
}

/**
 * @notice Builds the JSON attributes array for the token.
 * @param tokenId The ID of the token.
 * @return JSON string containing the attributes array, or empty string if none.
 */
function _buildAttributesJSON(uint256 tokenId) internal view returns (string memory) {
    string[] storage attributes = _tokenAttributes[tokenId];
    string[] storage values = _tokenValues[tokenId];
    if (attributes.length == 0) return "";

    string memory json = '"attributes": [';
    for (uint256 i = 0; i < attributes.length; i++) {
        json = string(
            abi.encodePacked(
                json,
                '{"trait_type": "', attributes[i], '", "value": "', values[i], '"}',
                i < attributes.length - 1 ? "," : ""
            )
        );
    }
    return string(abi.encodePacked(json, "],"));
}

/**
 * @notice Builds the JSON object containing current blockchain time and date.
 * @return JSON string with current time, date, and block timestamp.
 */
function _buildTimeJSON() internal view returns (string memory) {
    (uint256 hrs, uint256 mins, uint256 secs) = timestampToTime(block.timestamp);
    (uint256 year, uint256 month, uint256 day) = timestampToDate(block.timestamp);

    return string(
        abi.encodePacked(
            '"current_time": "', formatTime(hrs, mins, secs), '",',
            '"current_date": "', formatDate(year, month, day), '",',
            '"block_timestamp": ', block.timestamp.toString(), ','
        )
    );
}


    /**
     * @dev Get current blockchain time formatted
     */
    function getCurrentTime() external view returns (string memory timeString, string memory dateString, uint256 timestamp) {
        (uint256 hrs, uint256 mins, uint256 secs) = timestampToTime(block.timestamp);
        (uint256 year, uint256 month, uint256 day) = timestampToDate(block.timestamp);
        
        return (
            formatTime(hrs, mins, secs),
            formatDate(year, month, day),
            block.timestamp
        );
    }

    /**
     * @dev Get metadata for a token
     */
    function getTokenMetadata(uint256 tokenId) external view returns (
        string memory name,
        string memory description,
        string memory backgroundColor,
        string memory textColor,
        string[] memory attributes,
        string[] memory values
    ) {
        if (!_exists(tokenId)) {
            revert SvgNft_NotMinted();
        }
        
        TokenMetadata memory metadata = _tokenMetadata[tokenId];
        return (
            metadata.name,
            metadata.description,
            metadata.backgroundColor,
            metadata.textColor,
            _tokenAttributes[tokenId],
            _tokenValues[tokenId]
        );
    }

    /**
     * @dev Update token colors (only owner)
     */
    function updateTokenColors(
        uint256 tokenId,
        string memory backgroundColor,
        string memory textColor
    ) external onlyOwner {
        if (!_exists(tokenId)) {
            revert SvgNft_NotMinted();
        }

        _tokenMetadata[tokenId].backgroundColor = backgroundColor;
        _tokenMetadata[tokenId].textColor = textColor;
    }

    /**
     * @dev Burn an NFT
     */
    function burn(uint256 tokenId) public onlyOwner {
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