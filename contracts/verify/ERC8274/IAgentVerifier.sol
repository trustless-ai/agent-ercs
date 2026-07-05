// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IAgentVerifier — Stateful Agent Verification
/// @notice Outer verification layer: wraps one or more IProofVerifier instances
///         and answers "was this agent authorized, and did the proof verify?"
/// @dev    Part of ERC-8274 (AI Inference Proof Verification Interfaces).
///         Stateful — maintains agent-to-proof-verifier bindings.
interface IAgentVerifier {
    /// @notice Verify that an agent produced a given output from a given input,
    ///         with a valid cryptographic proof.
    /// @param  taskId             Unique identifier for the task
    /// @param  agentId            Identifier for the agent that performed inference
    /// @param  inputHash          keccak256 of the model input
    /// @param  outputHash         keccak256 of the model output
    /// @param  proof              The cryptographic proof bytes
    /// @return valid              True if the agent is authorized and proof verifies
    /// @return verificationDigest keccak256(abi.encode(taskId, agentId, inputHash,
    ///                              outputHash, valid, agentProofProfile))
    function verify(
        bytes32 taskId,
        bytes32 agentId,
        bytes32 inputHash,
        bytes32 outputHash,
        bytes calldata proof
    ) external returns (bool valid, bytes32 verificationDigest);

    /// @notice Emitted when a verification is completed.
    /// @dev Carries the full preimage fields for OCP recompute → compare → confirm.
    /// @param taskId             Unique identifier for the task
    /// @param agentId            Identifier for the agent
    /// @param inputHash          keccak256 of the model input
    /// @param outputHash         keccak256 of the model output
    /// @param valid              Whether the verification passed
    /// @param verificationDigest keccak256 of all preimage fields
    event VerificationCompleted(
        bytes32 indexed taskId,
        bytes32 indexed agentId,
        bytes32 inputHash,
        bytes32 outputHash,
        bool    valid,
        bytes32 verificationDigest
    );
}
