// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title ERC-7432 Non-Fungible Token Roles
 * @dev Interface for role-based access control on NFTs
 */

interface IERC7432 {
    struct RoleData {
        address user;
        uint64 expirationDate;
        bool revocable;
        bytes data;
    }

    /**
     * @notice Grants a role to a user for a specific token
     * @param tokenId The token ID
     * @param role The role identifier
     * @param user The user to grant the role to
     * @param expirationDate The expiration date of the role
     * @param revocable Whether the role can be revoked
     * @param data Additional role data
     */
    function grantRole(
        uint256 tokenId,
        bytes32 role,
        address user,
        uint64 expirationDate,
        bool revocable,
        bytes calldata data
    ) external;

    /**
     * @notice Revokes a role from a user for a specific token
     * @param tokenId The token ID
     * @param role The role identifier
     * @param user The user to revoke the role from
     */
    function revokeRole(uint256 tokenId, bytes32 role, address user) external;

    /**
     * @notice Checks if a user has a specific role for a token
     * @param tokenId The token ID
     * @param role The role identifier
     * @param user The user to check
     * @return Whether the user has the role
     */
    function hasRole(
        uint256 tokenId,
        bytes32 role,
        address user
    ) external view returns (bool);

    /**
     * @notice Gets role data for a specific token, role, and user
     * @param tokenId The token ID
     * @param role The role identifier
     * @param user The user
     * @return The role data
     */
    function roleData(
        uint256 tokenId,
        bytes32 role,
        address user
    ) external view returns (RoleData memory);
}
