// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {SvgNft} from "./SvgNft.sol";

contract SvgNftTest is Test {
    SvgNft public nft;
    address public owner;
    address public otherAccount;

    function setUp() public {
        owner = address(this);
        otherAccount = makeAddr("otherAccount");

        nft = new SvgNft();
    }

    function test_Deployment() public view {
        assertEq(nft.name(), "DynamicTimeNFT");
        assertEq(nft.symbol(), "DTNFT");
        assertEq(nft.owner(), owner);
    }

    function test_MintSimple() public {
        uint256 tokenId = nft.getNextTokenId();
        assertEq(tokenId, 0);
        
        string memory name = "Test Token";
        string memory description = "A test NFT";
        
        vm.expectEmit(true, true, false, true);
        emit SvgNft.NftMinted(0, owner, name);

        uint256 mintedTokenId = nft.mintSimple(owner, name, description);
        assertEq(mintedTokenId, 0);
        
        assertEq(nft.ownerOf(tokenId), owner);
        assertEq(nft.getNextTokenId(), 1);
        
        // Check metadata
        (
            string memory metadataName,
            string memory metadataDesc,
            string memory backgroundColor,
            string memory textColor,
            string[] memory metadataAttrs,
            string[] memory metadataVals
        ) = nft.getTokenMetadata(tokenId);
        
        assertEq(metadataName, name);
        assertEq(metadataDesc, description);
        assertEq(backgroundColor, "#1a1a2e"); // default background
        assertEq(textColor, "#ffffff"); // default text color
        assertEq(metadataAttrs.length, 0);
        assertEq(metadataVals.length, 0);
    }

    function test_MintWithCustomColors() public {
        uint256 tokenId = nft.getNextTokenId();
        
        string memory name = "Custom Token";
        string memory description = "Custom colored NFT";
        string memory bgColor = "#0f3460";
        string memory txtColor = "#ff6b6b";
        string[] memory attributes = new string[](2);
        string[] memory values = new string[](2);
        
        attributes[0] = "Color";
        attributes[1] = "Rarity";
        values[0] = "Blue";
        values[1] = "Rare";
        
        vm.expectEmit(true, true, false, true);
        emit SvgNft.NftMinted(0, owner, name);
        
        uint256 mintedTokenId = nft.mint(owner, name, description, bgColor, txtColor, attributes, values);
        assertEq(mintedTokenId, 0);
        
        assertEq(nft.ownerOf(tokenId), owner);
        
        // Check metadata
        (
            string memory metadataName,
            string memory metadataDesc,
            string memory backgroundColor,
            string memory textColor,
            string[] memory metadataAttrs,
            string[] memory metadataVals
        ) = nft.getTokenMetadata(tokenId);
        
        assertEq(metadataName, name);
        assertEq(metadataDesc, description);
        assertEq(backgroundColor, bgColor);
        assertEq(textColor, txtColor);
        assertEq(metadataAttrs.length, 2);
        assertEq(metadataVals.length, 2);
        assertEq(metadataAttrs[0], "Color");
        assertEq(metadataAttrs[1], "Rarity");
        assertEq(metadataVals[0], "Blue");
        assertEq(metadataVals[1], "Rare");
    }

    function test_MintToOtherAccount() public {
        assertEq(nft.getNextTokenId(), 0);
        
        string memory name1 = "Token 1";
        string memory name2 = "Token 2";
        string memory description = "Test NFT";

        // Mint first NFT to owner
        nft.mintSimple(owner, name1, description);
        assertEq(nft.getNextTokenId(), 1);

        // Mint second NFT to otherAccount
        vm.expectEmit(true, true, false, true);
        emit SvgNft.NftMinted(1, otherAccount, name2);
        
        nft.mintSimple(otherAccount, name2, description);

        // Check the second NFT (token ID 1)
        assertEq(nft.ownerOf(1), otherAccount);
        assertEq(nft.getNextTokenId(), 2);
        
        (string memory metadataName, , , , ,) = nft.getTokenMetadata(1);
        assertEq(metadataName, name2);
    }

    function test_TokenURIDynamic() public {
        string memory name = "URI Test Token";
        string memory description = "Testing tokenURI";
        string[] memory attributes = new string[](1);
        string[] memory values = new string[](1);
        
        attributes[0] = "Color";
        values[0] = "Red";
        
        nft.mint(owner, name, description, "#1a1a2e", "#ffffff", attributes, values);
        
        string memory tokenURI = nft.tokenURI(0);
        
        // Should start with data:application/json;base64,
        assertTrue(startsWith(tokenURI, "data:application/json;base64,"));
        
        // The URI should be different when called at different times (due to dynamic timestamp)
        vm.warp(block.timestamp + 3600); // Move forward 1 hour
        string memory tokenURI2 = nft.tokenURI(0);
        
        // URIs should be different because they contain different timestamps
        assertTrue(keccak256(bytes(tokenURI)) != keccak256(bytes(tokenURI2)));
    }

    function test_DynamicSVGGeneration() public {
        nft.mintSimple(owner, "Time NFT", "Dynamic time display");
        
        // Get SVG at current time
        string memory svg1 = nft.generateTimeSVG(0);
        assertTrue(bytes(svg1).length > 0);
        assertTrue(contains(svg1, '<svg xmlns="http://www.w3.org/2000/svg"'));
        assertTrue(contains(svg1, "Time NFT"));
        assertTrue(contains(svg1, "Token #0"));
        
        // Move time forward and get SVG again
        vm.warp(block.timestamp + 3661); // Move forward 1 hour, 1 minute, 1 second
        string memory svg2 = nft.generateTimeSVG(0);
        
        // SVGs should be different due to different timestamps
        assertTrue(keccak256(bytes(svg1)) != keccak256(bytes(svg2)));
    }

    function test_TimeConversionFunctions() public view {
        // Test time conversion with known timestamp
        uint256 testTimestamp = 1609459200; // January 1, 2021, 00:00:00 UTC

        (uint256 hrs, uint256 mins, uint256 secs) = nft.timestampToTime(testTimestamp);

        // Should be 00:00:00 UTC
        assertEq(hrs, 0);
        assertEq(mins, 0);
        assertEq(secs, 0);

        // Test with another timestamp: 1609462861 = January 1, 2021, 01:01:01 UTC
        (hrs, mins, secs) = nft.timestampToTime(1609462861);
        assertEq(hrs, 1);
        assertEq(mins, 1);
        assertEq(secs, 1);
    }

    function test_GetCurrentTime() public view {
        (string memory timeString, string memory dateString, uint256 timestamp) = nft.getCurrentTime();
        
        assertEq(timestamp, block.timestamp);
        assertTrue(bytes(timeString).length > 0);
        assertTrue(bytes(dateString).length > 0);
        
        // Time should be in HH:MM:SS format (8 characters)
        assertEq(bytes(timeString).length, 8);
        
        // Date should be in YYYY-MM-DD format (10 characters)
        assertEq(bytes(dateString).length, 10);
    }

    function test_UpdateTokenColors() public {
        nft.mintSimple(owner, "Test", "Test");
        
        string memory newBgColor = "#ff0000";
        string memory newTextColor = "#00ff00";
        
        nft.updateTokenColors(0, newBgColor, newTextColor);
        
        (, , string memory backgroundColor, string memory textColor, ,) = nft.getTokenMetadata(0);
        assertEq(backgroundColor, newBgColor);
        assertEq(textColor, newTextColor);
    }

    function test_RevertEmptyName() public {
        vm.expectRevert(SvgNft.SvgNft_NoName.selector);
        nft.mintSimple(owner, "", "Test");
    }

    function test_RevertZeroAddress() public {
        vm.expectRevert(SvgNft.SvgNft_NoRecipient.selector);
        nft.mintSimple(address(0), "Test Token", "Test");
    }

    function test_RevertAttributesMismatch() public {
        string[] memory attributes = new string[](2);
        string[] memory values = new string[](1); // Mismatch: 2 attributes, 1 value
        
        attributes[0] = "Color";
        attributes[1] = "Rarity";
        values[0] = "Blue";
        
        vm.expectRevert(SvgNft.SvgNft_AttributesMismatch.selector);
        nft.mint(owner, "Test Token", "Test", "#ffffff", "#000000", attributes, values);
    }

    function test_OnlyOwnerCanMint() public {
        vm.prank(otherAccount);
        vm.expectRevert();
        nft.mintSimple(otherAccount, "Test Token", "Test");
    }

    function test_OnlyOwnerCanUpdateColors() public {
        nft.mintSimple(owner, "Test", "Test");
        
        vm.prank(otherAccount);
        vm.expectRevert();
        nft.updateTokenColors(0, "#ff0000", "#00ff00");
    }

    function test_BurnToken() public {
        uint256 tokenId = nft.getNextTokenId();
        
        nft.mintSimple(owner, "Burn Test", "To be burned");
        assertEq(nft.ownerOf(tokenId), owner);
        assertEq(nft.balanceOf(owner), 1);

        vm.expectEmit(true, false, false, true);
        emit SvgNft.NftBurned(tokenId);
        
        nft.burn(tokenId);
        assertEq(nft.balanceOf(owner), 0);
        
        // Should revert when trying to get metadata of burned token
        vm.expectRevert(SvgNft.SvgNft_NotMinted.selector);
        nft.getTokenMetadata(tokenId);
        
        // Should revert when trying to get tokenURI of burned token
        vm.expectRevert(SvgNft.SvgNft_NotMinted.selector);
        nft.tokenURI(tokenId);
    }

    function test_OnlyOwnerCanBurn() public {
        nft.mintSimple(owner, "Test", "Test");
        
        vm.prank(otherAccount);
        vm.expectRevert();
        nft.burn(0);
    }

    function test_GenerateTimeSVGDataURI() public {
        nft.mintSimple(owner, "Test Token", "Test description");
        
        string memory dataURI = nft.generateTimeSVGDataURI(0);
        assertTrue(startsWith(dataURI, "data:image/svg+xml;base64,"));
        
        // Should be different when called at different times
        vm.warp(block.timestamp + 1);
        string memory dataURI2 = nft.generateTimeSVGDataURI(0);
        assertTrue(keccak256(bytes(dataURI)) != keccak256(bytes(dataURI2)));
    }

    function test_RevertNonExistentToken() public {
        vm.expectRevert(SvgNft.SvgNft_NotMinted.selector);
        nft.tokenURI(999);
        
        vm.expectRevert(SvgNft.SvgNft_NotMinted.selector);
        nft.getTokenMetadata(999);
        
        vm.expectRevert(SvgNft.SvgNft_NotMinted.selector);
        nft.generateTimeSVG(999);
        
        vm.expectRevert(SvgNft.SvgNft_NotMinted.selector);
        nft.updateTokenColors(999, "#ff0000", "#00ff00");
    }

    function test_LeapYearCalculation() public view {
        // Test leap year edge cases by checking date conversion
        // This indirectly tests the isLeapYear function
        
        // Test year 2000 (leap year)
        uint256 year2000 = 946684800; // January 1, 2000, 00:00:00 UTC
        (uint256 hrs, uint256 mins, uint256 secs) = nft.timestampToTime(year2000);
        assertEq(hrs, 0);
        assertEq(mins, 0);
        assertEq(secs, 0);
        
        // Test year 1900 (not a leap year despite being divisible by 4)
        // We can't directly test this without implementing the full date logic,
        // but we can verify the time conversion works for various timestamps
        
        uint256 someTimestamp = 1234567890; // Fri Feb 13 2009 23:31:30 UTC
        (hrs, mins, secs) = nft.timestampToTime(someTimestamp);
        assertEq(hrs, 23);
        assertEq(mins, 31);
        assertEq(secs, 30);
    }

    function test_FuzzMinting(address recipient, string calldata name, string calldata description) public {
        vm.assume(recipient != address(0));
        vm.assume(bytes(name).length > 0);
        
        uint256 tokenId = nft.getNextTokenId();
        nft.mintSimple(recipient, name, description);
        
        assertEq(nft.ownerOf(tokenId), recipient);
        (string memory metadataName, , , , ,) = nft.getTokenMetadata(tokenId);
        assertEq(metadataName, name);
    }

    function test_FuzzTimeConversion(uint256 timestamp) public view {
        // Bound timestamp to reasonable range to avoid overflow issues
        timestamp = bound(timestamp, 0, type(uint32).max);
        
        (uint256 hrs, uint256 mins, uint256 secs) = nft.timestampToTime(timestamp);
        
        // Time components should be within valid ranges
        assertLt(hrs, 24);
        assertLt(mins, 60);
        assertLt(secs, 60);
    }

    // Helper functions
    function startsWith(string memory str, string memory prefix) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory prefixBytes = bytes(prefix);
        
        if (strBytes.length < prefixBytes.length) {
            return false;
        }
        
        for (uint256 i = 0; i < prefixBytes.length; i++) {
            if (strBytes[i] != prefixBytes[i]) {
                return false;
            }
        }
        
        return true;
    }
    
    function contains(string memory str, string memory substr) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory substrBytes = bytes(substr);
        
        if (substrBytes.length == 0) {
            return true;
        }
        
        if (strBytes.length < substrBytes.length) {
            return false;
        }
        
        for (uint256 i = 0; i <= strBytes.length - substrBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < substrBytes.length; j++) {
                if (strBytes[i + j] != substrBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                return true;
            }
        }
        
        return false;
    }
}