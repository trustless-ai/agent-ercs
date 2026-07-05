// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title IIdentityRegistry — Agent Identity Registration
/// @notice Minimal on-chain handle based on ERC-721 that resolves to an agent's
///         registration file, providing a portable, censorship-resistant identifier.
/// @dev    Part of ERC-8004 (Trustless Agents).
///         Extends IERC721 with agent-specific metadata and wallet management.
interface IIdentityRegistry is IERC721 {
    // ── Registration ─────────────────────────────────────────────────────────

    /// @notice Metadata entry for agent registration.
    struct MetadataEntry {
        string metadataKey;
        bytes  metadataValue;
    }

    /// @notice Register a new agent with a URI and optional metadata.
    /// @param  agentURI The URI resolving to the agent registration file
    /// @param  metadata Optional on-chain metadata entries
    /// @return agentId  The ERC-721 tokenId assigned to the new agent
    function register(
        string calldata agentURI,
        MetadataEntry[] calldata metadata
    ) external returns (uint256 agentId);

    /// @notice Register a new agent with a URI and no metadata.
    /// @param  agentURI The URI resolving to the agent registration file
    /// @return agentId  The ERC-721 tokenId assigned to the new agent
    function register(string calldata agentURI) external returns (uint256 agentId);

    /// @notice Register a new agent without a URI (set later via setAgentURI).
    /// @return agentId The ERC-721 tokenId assigned to the new agent
    function register() external returns (uint256 agentId);

    /// @notice Update the agent registration file URI.
    /// @param  agentId  The agent's tokenId
    /// @param  agentURI The new URI resolving to the agent registration file
    function setAgentURI(uint256 agentId, string calldata agentURI) external;

    // ── On-Chain Metadata ────────────────────────────────────────────────────

    /// @notice Get an on-chain metadata value for an agent.
    /// @param  agentId     The agent's tokenId
    /// @param  metadataKey The metadata key to look up
    /// @return             The stored metadata value
    function getMetadata(
        uint256 agentId,
        string calldata metadataKey
    ) external view returns (bytes memory);

    /// @notice Set an on-chain metadata value for an agent.
    /// @param  agentId      The agent's tokenId
    /// @param  metadataKey  The metadata key to set
    /// @param  metadataValue The value to store
    function setMetadata(
        uint256 agentId,
        string calldata metadataKey,
        bytes calldata metadataValue
    ) external;

    // ── Agent Wallet ─────────────────────────────────────────────────────────

    /// @notice Set the agent's payment wallet (requires EIP-712/ERC-1271 proof of control).
    /// @param  agentId   The agent's tokenId
    /// @param  newWallet The address where the agent receives payments
    /// @param  deadline  Signature expiry timestamp
    /// @param  signature EIP-712 or ERC-1271 signature proving wallet control
    function setAgentWallet(
        uint256 agentId,
        address newWallet,
        uint256 deadline,
        bytes calldata signature
    ) external;

    /// @notice Get the agent's current payment wallet.
    /// @param  agentId The agent's tokenId
    /// @return         The address where the agent receives payments
    function getAgentWallet(uint256 agentId) external view returns (address);

    /// @notice Clear the agent's payment wallet (reset to zero address).
    /// @param  agentId The agent's tokenId
    function unsetAgentWallet(uint256 agentId) external;

    // ── Events ───────────────────────────────────────────────────────────────

    /// @notice Emitted when a new agent is registered.
    event Registered(uint256 indexed agentId, string agentURI, address indexed owner);

    /// @notice Emitted when on-chain metadata is set.
    event MetadataSet(
        uint256 indexed agentId,
        string  indexed indexedMetadataKey,
        string           metadataKey,
        bytes            metadataValue
    );
}
