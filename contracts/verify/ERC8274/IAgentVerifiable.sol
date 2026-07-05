// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IAgentVerifiable — Declare Which Verifier Validates This Contract
/// @notice Declaration layer: a settlement or execution contract announces
///         which IAgentVerifier it trusts for proof verification.
/// @dev    Part of ERC-8274 (AI Inference Proof Verification Interfaces).
///         Settlement contracts never interact with IProofVerifier directly;
///         they route through the IAgentVerifier declared here.
interface IAgentVerifiable {
    /// @notice Returns the IAgentVerifier trusted by this contract.
    /// @return The address of the IAgentVerifier implementation
    function agentVerifier() external view returns (address);

    /// @notice Emitted when the trusted IAgentVerifier is updated.
    /// @param oldVerifier Previous verifier address
    /// @param newVerifier New verifier address
    event AgentVerifierUpdated(address indexed oldVerifier, address indexed newVerifier);
}
