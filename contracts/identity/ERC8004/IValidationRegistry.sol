// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IValidationRegistry — Agent Validation Request & Response
/// @notice Generic hooks for requesting and recording independent validator checks
///         (e.g., stakers re-running jobs, zkML verifiers, TEE oracles, trusted judges).
/// @dev    Part of ERC-8004 (Trustless Agents).
///         Incentives and slashing are managed by specific validation protocols
///         and are outside the scope of this registry.
interface IValidationRegistry {
    // ── Validation Request ───────────────────────────────────────────────────

    /// @notice Request validation of an agent's work.
    /// @dev    MUST be called by the owner or operator of agentId.
    /// @param  validatorAddress The validator contract to perform the check
    /// @param  agentId          The agent whose work is to be validated
    /// @param  requestURI       URI to off-chain data with inputs/outputs for validation
    /// @param  requestHash      keccak256 of the request payload (identifies the request)
    function validationRequest(
        address validatorAddress,
        uint256 agentId,
        string calldata requestURI,
        bytes32 requestHash
    ) external;

    // ── Validation Response ──────────────────────────────────────────────────

    /// @notice Respond to a validation request.
    /// @dev    MUST be called by the validatorAddress specified in the original request.
    ///         Can be called multiple times for progressive validation states.
    /// @param  requestHash  The request being responded to
    /// @param  response     Validation result: 0 (failed) to 100 (passed), or intermediate
    /// @param  responseURI  Optional URI to off-chain evidence or audit
    /// @param  responseHash keccak256 of responseURI content (omit for IPFS)
    /// @param  tag          Optional tag for categorization (e.g., "soft-finality")
    function validationResponse(
        bytes32 requestHash,
        uint8   response,
        string calldata responseURI,
        bytes32 responseHash,
        string calldata tag
    ) external;

    // ── Read Functions ───────────────────────────────────────────────────────

    /// @notice Get the current validation status for a request.
    /// @param  requestHash     The request to query
    /// @return validatorAddress The validator that handled this request
    /// @return agentId          The agent whose work was validated
    /// @return response         The validation result (0-100)
    /// @return responseHash     keccak256 of the response payload
    /// @return tag              The response tag
    /// @return lastUpdate       Timestamp of the last update
    function getValidationStatus(bytes32 requestHash)
        external view
        returns (
            address validatorAddress,
            uint256 agentId,
            uint8   response,
            bytes32 responseHash,
            string  memory tag,
            uint256 lastUpdate
        );

    /// @notice Get aggregated validation statistics for an agent.
    /// @param  agentId           The agent to query
    /// @param  validatorAddresses Optional filter by validator addresses
    /// @param  tag               Optional tag filter
    /// @return count             Number of validations matching the filters
    /// @return averageResponse   Average response value
    function getSummary(
        uint256 agentId,
        address[] calldata validatorAddresses,
        string calldata tag
    ) external view returns (uint64 count, uint8 averageResponse);

    /// @notice Get all validation request hashes for an agent.
    /// @param  agentId        The agent to query
    /// @return requestHashes  Array of request hashes
    function getAgentValidations(uint256 agentId)
        external view
        returns (bytes32[] memory requestHashes);

    /// @notice Get all validation request hashes handled by a validator.
    /// @param  validatorAddress The validator to query
    /// @return requestHashes    Array of request hashes
    function getValidatorRequests(address validatorAddress)
        external view
        returns (bytes32[] memory requestHashes);

    // ── Identity Registry Link ───────────────────────────────────────────────

    /// @notice Returns the Identity Registry address this Validation Registry is linked to.
    /// @return identityRegistry The IIdentityRegistry contract address
    function getIdentityRegistry() external view returns (address);

    // ── Events ───────────────────────────────────────────────────────────────

    /// @notice Emitted when a validation is requested.
    event ValidationRequest(
        address indexed validatorAddress,
        uint256 indexed agentId,
        string           requestURI,
        bytes32 indexed requestHash
    );

    /// @notice Emitted when a validator responds to a request.
    event ValidationResponse(
        address indexed validatorAddress,
        uint256 indexed agentId,
        bytes32 indexed requestHash,
        uint8   response,
        string  responseURI,
        bytes32 responseHash,
        string  tag
    );
}
