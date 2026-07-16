// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IObservationCommitment — On-chain Commitment Anchor (ERC-8281)
/// @notice Observation Commitment Protocol (OCP): anchors an opaque commitment
///         `digest` on-chain as tamper-evident proof (timestamped by its block) that
///         an observation was committed to, without revealing the observation itself.
/// @dev    Verification is off-chain and recompute-based: a verifier re-derives the
///         digest from the primary artifact and confirms the matching {Recorded} log
///         exists — the proof envelope pins `chain_id` and the receipt log position
///         for unambiguous selection. The interface exposes no getter; the event log
///         is the ledger. ERC-165 interface id `0xb5c645bd` is implemented by the
///         reference contract, not by this interface. Minimal anchor primitive of the
///         AI-inference trust stack: ERC-8299 (WYRIWE) anchors its L3 input-provenance
///         commitment through this surface.
interface IObservationCommitment {
    /// @notice Commit a digest on-chain.
    /// @param digest The hash of the observation bytes, produced using a hash
    ///        function from the allowed set defined in ERC-8281.
    function record(bytes32 digest) external;

    /// @notice Emitted on every successful {record} call.
    /// @param digest    The committed digest (topics[1]).
    /// @param committer The address that called {record} (topics[2]).
    event Recorded(bytes32 indexed digest, address indexed committer);
}
