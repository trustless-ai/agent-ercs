// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IProofVerifier — Stateless Cryptographic Proof Verification
/// @notice Inner verification layer: answers "is this proof cryptographically valid
///         for the given input/output pair?"
/// @dev    Part of ERC-8274 (AI Inference Proof Verification Interfaces).
///         Stateless and proof-system-agnostic. Each proof system (zkML, opML, TEE)
///         deploys its own IProofVerifier implementation.
interface IProofVerifier {
    /// @notice Verify a cryptographic proof for a given (inputHash, outputHash) pair.
    /// @param  inputHash  keccak256 of the model input
    /// @param  outputHash keccak256 of the model output
    /// @param  metadata   Proof-system-specific metadata (e.g. model identifier, version)
    /// @param  proof      The cryptographic proof bytes
    /// @return valid      True if the proof is cryptographically valid
    function verify(
        bytes32 inputHash,
        bytes32 outputHash,
        bytes calldata metadata,
        bytes calldata proof
    ) external returns (bool valid);

    /// @notice Human-readable identifier for this proof system.
    /// @return Identifier string (e.g. "zkML-Halo2", "opML-V1", "TEE-DCAP")
    function proofSystem() external view returns (string memory);

    /// @notice Compact proof profile identifier for on-chain lookups.
    /// @return Proof profile hash (e.g. keccak256 of proof system + version + circuit)
    function proofProfile() external view returns (bytes32);
}
