// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IReputationRegistry — Agent Feedback & Reputation Signals
/// @notice Standard interface for posting and fetching feedback signals about agents.
///         Scoring and aggregation occur both on-chain (for composability) and
///         off-chain (for sophisticated algorithms).
/// @dev    Part of ERC-8004 (Trustless Agents).
///         Feedback is given by client addresses and identified by (agentId, clientAddress, feedbackIndex).
interface IReputationRegistry {
    // ── Giving Feedback ──────────────────────────────────────────────────────

    /// @notice Submit feedback for an agent.
    /// @param  agentId        The agent receiving feedback; must be registered
    /// @param  value          Fixed-point feedback score
    /// @param  valueDecimals  Decimal places for value (0-18)
    /// @param  tag1           Optional primary tag for categorization
    /// @param  tag2           Optional secondary tag for categorization
    /// @param  endpoint       Optional endpoint URI related to the feedback
    /// @param  feedbackURI    Optional URI to off-chain feedback detail file
    /// @param  feedbackHash   keccak256 of feedbackURI content (omit for IPFS)
    function giveFeedback(
        uint256 agentId,
        int128  value,
        uint8   valueDecimals,
        string calldata tag1,
        string calldata tag2,
        string calldata endpoint,
        string calldata feedbackURI,
        bytes32 feedbackHash
    ) external;

    /// @notice Revoke previously submitted feedback.
    /// @param  agentId       The agent the feedback was given to
    /// @param  feedbackIndex The 1-indexed feedback counter from this client
    function revokeFeedback(uint256 agentId, uint64 feedbackIndex) external;

    /// @notice Append a response to existing feedback.
    /// @param  agentId       The agent the feedback was given to
    /// @param  clientAddress The address that gave the feedback
    /// @param  feedbackIndex The 1-indexed feedback counter
    /// @param  responseURI   URI to off-chain response detail file
    /// @param  responseHash  keccak256 of responseURI content (omit for IPFS)
    function appendResponse(
        uint256 agentId,
        address clientAddress,
        uint64  feedbackIndex,
        string calldata responseURI,
        bytes32 responseHash
    ) external;

    // ── Read Functions ───────────────────────────────────────────────────────

    /// @notice Get aggregated feedback summary for an agent.
    /// @param  agentId         The agent to query
    /// @param  clientAddresses Filter by these client addresses (mandatory)
    /// @param  tag1            Optional tag1 filter
    /// @param  tag2            Optional tag2 filter
    /// @return count           Number of feedback entries matching the filters
    /// @return summaryValue    Aggregated value (method is implementation-defined)
    /// @return summaryValueDecimals Decimal places for summaryValue
    function getSummary(
        uint256 agentId,
        address[] calldata clientAddresses,
        string calldata tag1,
        string calldata tag2
    ) external view returns (uint64 count, int128 summaryValue, uint8 summaryValueDecimals);

    /// @notice Read a single feedback entry.
    /// @param  agentId       The agent
    /// @param  clientAddress The feedback giver
    /// @param  feedbackIndex The 1-indexed feedback counter
    /// @return value         Feedback score
    /// @return valueDecimals Decimal places for value
    /// @return tag1          Primary tag
    /// @return tag2          Secondary tag
    /// @return isRevoked     Whether this feedback has been revoked
    function readFeedback(
        uint256 agentId,
        address clientAddress,
        uint64  feedbackIndex
    ) external view returns (
        int128 value,
        uint8  valueDecimals,
        string memory tag1,
        string memory tag2,
        bool   isRevoked
    );

    /// @notice Read all feedback for an agent with optional filters.
    /// @param  agentId         The agent to query
    /// @param  clientAddresses Filter by these client addresses (optional)
    /// @param  tag1            Optional tag1 filter
    /// @param  tag2            Optional tag2 filter
    /// @param  includeRevoked  Whether to include revoked feedback
    /// @return clients         Array of client addresses
    /// @return feedbackIndexes Array of feedback indices
    /// @return values          Array of feedback scores
    /// @return valueDecimalss  Array of value decimal places
    /// @return tag1s           Array of primary tags
    /// @return tag2s           Array of secondary tags
    /// @return revokedStatuses Array of revocation statuses
    function readAllFeedback(
        uint256 agentId,
        address[] calldata clientAddresses,
        string calldata tag1,
        string calldata tag2,
        bool includeRevoked
    ) external view returns (
        address[] memory clients,
        uint64[]  memory feedbackIndexes,
        int128[]  memory values,
        uint8[]   memory valueDecimalss,
        string[]  memory tag1s,
        string[]  memory tag2s,
        bool[]    memory revokedStatuses
    );

    /// @notice Get the count of responses for a feedback entry.
    /// @param  agentId       The agent
    /// @param  clientAddress The feedback giver
    /// @param  feedbackIndex The 1-indexed feedback counter
    /// @param  responders    Filter by responder addresses (optional)
    /// @return count         Number of responses
    function getResponseCount(
        uint256 agentId,
        address clientAddress,
        uint64  feedbackIndex,
        address[] calldata responders
    ) external view returns (uint64 count);

    /// @notice Get all client addresses that have given feedback to an agent.
    /// @param  agentId The agent to query
    /// @return         Array of client addresses
    function getClients(uint256 agentId) external view returns (address[] memory);

    /// @notice Get the last feedback index from a client for an agent.
    /// @param  agentId       The agent
    /// @param  clientAddress The feedback giver
    /// @return               The last 1-indexed feedback counter
    function getLastIndex(
        uint256 agentId,
        address clientAddress
    ) external view returns (uint64);

    // ── Identity Registry Link ───────────────────────────────────────────────

    /// @notice Returns the Identity Registry address this Reputation Registry is linked to.
    /// @return identityRegistry The IIdentityRegistry contract address
    function getIdentityRegistry() external view returns (address);

    // ── Events ───────────────────────────────────────────────────────────────

    /// @notice Emitted when new feedback is submitted.
    event NewFeedback(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint64           feedbackIndex,
        int128  value,
        uint8   valueDecimals,
        string  indexed indexedTag1,
        string  tag1,
        string  tag2,
        string  endpoint,
        string  feedbackURI,
        bytes32 feedbackHash
    );

    /// @notice Emitted when feedback is revoked.
    event FeedbackRevoked(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint64  indexed feedbackIndex
    );

    /// @notice Emitted when a response is appended to feedback.
    event ResponseAppended(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint64           feedbackIndex,
        address responder,
        string  responseURI,
        bytes32 responseHash
    );
}
