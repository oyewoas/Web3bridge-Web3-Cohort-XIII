// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IERC7432.sol";
import {RoleNFTErrors} from "./libraries/Errors.sol";
import {RoleNFTEvents} from "./libraries/Events.sol";

/**
 * @title RoleNFT
 * @dev NFT contract implementing ERC-7432 role functionality
 */
contract RoleNFT is ERC721, Ownable, IERC7432 {
    uint256 private _nextTokenId = 1;
    uint256 private _totalSupply;

    // tokenId => role => user => RoleData
    mapping(uint256 => mapping(bytes32 => mapping(address => RoleData)))
        private _roleData;

    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) Ownable(msg.sender) {}

    /**
     * @notice Mints a new NFT
     * @param to The recipient address
     * @return The token ID of the minted NFT
     */
    function mint(address to) external onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
        _totalSupply++;
        return tokenId;
    }

    /**
     * @notice Burns an NFT
     * @param tokenId The token ID to burn
     */
    function burn(uint256 tokenId) external onlyOwner {
        if (!_exists(tokenId))
            revert RoleNFTErrors.RoleNFT_TokenDoesNotExist(tokenId);
        _burn(tokenId);
        _totalSupply--;
    }

    /**
     * @notice Grants a role to a user for a specific token
     */
    function grantRole(
        uint256 tokenId,
        bytes32 role,
        address user,
        uint64 expirationDate,
        bool revocable,
        bytes calldata data
    ) external override {
        if (!_exists(tokenId))
            revert RoleNFTErrors.RoleNFT_TokenDoesNotExist(tokenId);

        if (
            !(ownerOf(tokenId) == msg.sender ||
                getApproved(tokenId) == msg.sender ||
                isApprovedForAll(ownerOf(tokenId), msg.sender))
        ) revert RoleNFTErrors.RoleNFT_NotAuthorized(tokenId, role, user);

        if (!(expirationDate > block.timestamp || expirationDate == 0))
            revert RoleNFTErrors.RoleNFT_InvalidExpiration(tokenId, role, user);

        _storeRoleData(tokenId, role, user, expirationDate, revocable, data);

        emit RoleNFTEvents.RoleGranted(tokenId, role, user, expirationDate);
    }

    /**
     * @notice Revokes a role from a user for a specific token
     */
    function revokeRole(
        uint256 tokenId,
        bytes32 role,
        address user
    ) external override {
        if (!_exists(tokenId))
            revert RoleNFTErrors.RoleNFT_TokenDoesNotExist(tokenId);

        RoleData memory roleDataStruct = _roleData[tokenId][role][user];
        if (roleDataStruct.user == address(0))
            revert RoleNFTErrors.RoleNFT_RoleNotGranted(tokenId, role, user);
        if (!roleDataStruct.revocable)
            revert RoleNFTErrors.RoleNFT_RoleNotRevocable(tokenId, role, user);
        if (
    !(ownerOf(tokenId) == msg.sender ||
      getApproved(tokenId) == msg.sender ||
      isApprovedForAll(ownerOf(tokenId), msg.sender))
)
    revert RoleNFTErrors.RoleNFT_NotAuthorized(tokenId, role, user);

        delete _roleData[tokenId][role][user];

        emit RoleNFTEvents.RoleRevoked(tokenId, role, user);
    }

    /**
     * @notice Checks if a user has a specific role for a token
     */
    function hasRole(
        uint256 tokenId,
        bytes32 role,
        address user
    ) external view override returns (bool) {
        if (!_exists(tokenId)) return false;

        RoleData memory roleDataStruct = _roleData[tokenId][role][user];
        if (roleDataStruct.user == address(0)) return false;

        // Check if role has expired (0 means no expiration)
        if (
            roleDataStruct.expirationDate != 0 &&
            roleDataStruct.expirationDate <= block.timestamp
        ) {
            return false;
        }

        return true;
    }

    /**
     * @notice Gets role data for a specific token, role, and user
     */
    function roleData(
        uint256 tokenId,
        bytes32 role,
        address user
    ) external view override returns (RoleData memory) {
        return _roleData[tokenId][role][user];
    }

    /**
     * @notice Checks if token exists
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /**
     * @notice Internal function to store role data
     */
    function _storeRoleData(
        uint256 tokenId,
        bytes32 role,
        address user,
        uint64 expirationDate,
        bool revocable,
        bytes calldata data
    ) internal {
        _roleData[tokenId][role][user] = RoleData({
            user: user,
            expirationDate: expirationDate,
            revocable: revocable,
            data: data
        });
    }

    /**
     * @notice Returns the total number of tokens minted
     */
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }
}
