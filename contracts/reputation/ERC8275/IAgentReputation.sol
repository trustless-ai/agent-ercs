// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IClaimType} from "../../interfaces/IClaimType.sol";

/// @title IAgentReputation — Event-Derived Agent Reputation (ERC-8275 Part I, Reputation Layer)
/// @notice Reputation is derived entirely from IAgentEscrow settlement events and, optionally,
///         verified ERC-8299 (WYRIWE) attestation history — derived-not-stored: every value is
///         recomputable from public data, with no scorer to trust.
/// @dev    Part of ERC-8275 (Agent Service Discovery and Escrow Payments). Recommended scoring
///         shape: f(attestationCount, counterpartyDiversity, winRate, volumeCap) — losses stay
///         in the record, weighting favours distinct at-stake counterparties over call volume,
///         and volumeCap ceilings the volume weight by (winRate x settled-count) so raw call
///         volume alone cannot dominate the outcome axis. See spec Appendix A.3 for the full
///         per-field attestation -> reputation-input mapping (primary-authored by babyblueviper1,
///         production reference api.babyblueviper.com/ledger) and the recompute path any party
///         can run against public data alone, with no trust in the issuer.
interface IAgentReputation is IClaimType {
    /// @notice ValidatorType Enum (for attestation-gated scoring) — the on-chain-schema-facing
    ///         discriminator, structurally identical to IClaimType.ClaimType (ReExecution=0,
    ///         Attestation=1, Judgment=2) by spec design. Dual discriminator per the spec: an
    ///         EIP-712 type string carries on-chain schema discrimination, this enum carries
    ///         off-chain indexer readability — the two MUST NOT be conflated with each other's
    ///         role, only kept in sync on values.
    enum ValidatorType {
        ReExecution,
        Attestation,
        Judgment
    }

    /// @notice Current reputation snapshot for an agent, recomputable from public Escrow events.
    /// @param completedOrders Count of orders settled without dispute.
    /// @param disputedOrders  Count of orders that entered dispute/challenge.
    /// @param totalVolume     Cumulative settled volume across all orders (implementation-defined unit).
    /// @param lastActiveAt    Unix timestamp of the most recent settlement event.
    /// @param score           Derived score per f(attestationCount, counterpartyDiversity, winRate, volumeCap).
    function getReputation(bytes32 agentId)
        external
        view
        returns (
            uint64 completedOrders,
            uint64 disputedOrders,
            uint64 totalVolume,
            uint64 lastActiveAt,
            uint16 score
        );

    /// @notice Recency-decay weight applied to `score` — older activity counts for less.
    /// @return weight Decay weight in basis points (10000 = no decay).
    function getDecayWeight(bytes32 agentId) external view returns (uint16 weight);

    /// @notice Verify a settled order's outcome proof against the public Escrow record, so a
    ///         consumer can confirm win/loss attribution without trusting this contract's own
    ///         `getReputation` aggregate.
    /// @param orderId Identifier of the settled order.
    /// @param proof   Implementation-defined proof of the settled outcome (e.g. Merkle proof
    ///                against a published settlement root, or a direct event-log reference).
    /// @return valid True if the outcome resolves as claimed against public on-chain data.
    function verifyOutcome(bytes32 orderId, bytes calldata proof) external view returns (bool valid);
}
