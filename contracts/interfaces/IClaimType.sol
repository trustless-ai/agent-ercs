// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IClaimType — Accountability Model Discriminator
/// @notice Cross-domain claim classification carried inside signed proof-verification
///         artifacts, distinct from `proofSystem` (the cryptographic mechanism).
/// @dev    Defined by ERC-8299 (WYRIWE) Section 7. Shared across any ERC whose signed
///         artifacts need to declare an accountability/dispute model to an off-chain
///         consumer holding only the raw struct (no registry lookup).
interface IClaimType {
    /// @notice Accountability model backing a claim.
    /// @dev `proofSystem` answers "what cryptographic mechanism authenticated this?";
    ///      `claimType` answers "what kind of accountability model backs this claim?"
    ///      The two MUST NOT be conflated — e.g. `sig/eip712` backs both Attestation
    ///      and Judgment claims, so proofSystem alone cannot distinguish them.
    enum ClaimType {
        ReExecution, // deterministic computation — objectively disputable
        Attestation, // authorized signer certifies a result
        Judgment     // subjective assessment — accountable through track record / policy
    }
}
