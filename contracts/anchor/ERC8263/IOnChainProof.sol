// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IOnChainProof — Onchain Proof Layer for AI Agents (ERC-8263)
/// @notice Write-side anchor floor of the trustless AI agent stack: an agent (or its
///         operator) anchors a cryptographic commitment to an action — `proofHash` —
///         together with an identity-scheme byte and a 32-byte agent identifier,
///         producing a verifiable, immutable timeline of agent activity.
/// @dev    Exactly one canonical event, {AnchorProof}, is emitted for every successful
///         anchor across both entrypoints, so indexers parse a single topic0:
///         keccak256("AnchorProof(uint8,bytes32,bytes32,address,bytes)")
///         = 0x9fe832d83a52f83bd7d54181e4cc7ff8b4e227cc1d3a0144376894b5df6c23cc.
///
///         agentIdScheme registry (enforced at write time by canonical-form guards):
///           0x00 ANONYMOUS — agentId MUST be bytes32(0)
///           0x01 REGISTRY  — agentId is a 32-byte registry record id (e.g. ERC-8004);
///                            MUST be non-zero
///           0x02 URI_HASH  — agentId = keccak256(canonical agent URI); MUST be non-zero
///           0x03+ reserved — MUST revert
///         `proofHash` MUST be non-zero. The contract does not constrain the hash
///         algorithm or canonicalization producing `proofHash`; profile-level rules
///         apply at the commitment layer (see the ERC's "Recommended proofHash
///         Constructions").
///
///         Composition: identity binding under scheme 0x01 belongs to an identity
///         registry (ERC-8004 or compatible); observation extraction and re-check
///         digests belong to OCP (ERC-8281); output verification belongs to the
///         inference-verification layer (ERC-8274); input-provenance discipline is a
///         profile concern (ERC-8299). This interface stays neutral: anchors are valid
///         for verifiers that ignore all adjacent layers and check `proofHash` against
///         their own profile from chain state alone.
interface IOnChainProof {
    /// @notice Emitted exactly once for every successful anchor.
    /// @param agentIdScheme Identity scheme byte (data segment, deliberately not
    ///        indexed so indexers always decode it together with `agentId`).
    /// @param agentId       32-byte agent identifier per `agentIdScheme` (topics[1]).
    /// @param proofHash     Non-zero 32-byte commitment to the action (topics[2]).
    /// @param operator      Transaction submitter (topics[3]); NOT an authorization
    ///        claim — authorization belongs to higher-layer verifier profiles.
    /// @param aux           Opaque, explicitly non-normative extension bytes.
    ///        Indexers MUST treat `aux` as opaque and MUST NOT derive proof
    ///        semantics from it.
    event AnchorProof(
        uint8           agentIdScheme,
        bytes32 indexed agentId,
        bytes32 indexed proofHash,
        address indexed operator,
        bytes           aux
    );

    /// @notice Minimal anchor: empty aux, lowest calldata cost.
    /// @param agentIdScheme Identity scheme byte (0x00, 0x01, or 0x02).
    /// @param agentId       32-byte agent identifier per the scheme registry.
    /// @param proofHash     Non-zero 32-byte commitment to the action.
    function anchor(
        uint8   agentIdScheme,
        bytes32 agentId,
        bytes32 proofHash
    ) external;

    /// @notice Extended anchor with opaque aux bytes for adjacent protocols.
    /// @param agentIdScheme Identity scheme byte (0x00, 0x01, or 0x02).
    /// @param agentId       32-byte agent identifier per the scheme registry.
    /// @param proofHash     Non-zero 32-byte commitment to the action.
    /// @param aux           Opaque extension bytes (non-normative; e.g. OCP digest
    ///        commitments, session ids, parent-proof references).
    function anchorWithAux(
        uint8   agentIdScheme,
        bytes32 agentId,
        bytes32 proofHash,
        bytes calldata aux
    ) external;
}
