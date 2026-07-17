// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title IBoundedAgentAction — Bounded Agent Actions
/// @notice On-chain envelope for an agent mandate: a principal, an immutable
///         capability commitment, a mutable consumption commitment (the cursor),
///         an expiry, and a lifecycle status. The cursor is the one written
///         object every value-drawing surface advances, so the aggregate
///         consumption of a mandate exists where no single protocol maintains it.
/// @dev    Part of ERC-8312 (Bounded Agent Actions), ethereum/ERCs PR #1833.
///         The cursor METERS consumption; it does not enforce. Non-bypassability
///         is a substrate property: a registry claiming its bound cannot be
///         bypassed must document the mechanism that routes value through
///         advanceCursor. ERC-165 interfaceId: 0x3985961d (frozen; regenerate
///         if any function signature changes).

interface IBoundedAgentAction is IERC165 {
    // ── Enums ────────────────────────────────────────────────────────────────

    /// @notice Lifecycle status of an envelope.
    enum Status {
        None, // 0: nonexistent / not registered
        Active,
        Completed,
        Contested,
        Revoked,
        Expired
    }

    // ── Data Structures ──────────────────────────────────────────────────────

    /// @notice The envelope: one registered bounded mandate.
    /// @dev    capabilityRoot commits to the agreed authority (for an ERC-8001
    ///         agreement, to the capability structure derived from it) and is
    ///         immutable after registration. cursorRoot commits to aggregate
    ///         consumption state and changes only through advanceCursor.
    struct Envelope {
        bytes32 id;
        address principal;
        bytes32 capabilityRoot;
        bytes32 cursorRoot;
        uint64 createdAt;
        uint64 expiresAt;
        Status status;
    }

    // ── Events ───────────────────────────────────────────────────────────────

    /// @notice Emitted on successful registration. Initial status is Active.
    event EnvelopeRegistered(
        bytes32 indexed id,
        address indexed principal,
        bytes32 indexed capabilityRoot
    );

    /// @notice Emitted on every cursor advance. The public advance record is
    ///         what makes cumulative consumption recomputable by any party.
    event EnvelopeAdvanced(
        bytes32 indexed id,
        bytes32 prevCursor,
        bytes32 newCursor
    );

    /// @notice Emitted on every status transition.
    event EnvelopeStatusChanged(
        bytes32 indexed id,
        Status fromStatus,
        Status toStatus
    );

    // ── Functions ────────────────────────────────────────────────────────────

    /// @notice Register a new envelope. The id MUST be unique within the
    ///         registry, including against terminal envelopes. If principal is
    ///         not the caller, the implementation MUST verify the principal
    ///         authorized the registration.
    function registerEnvelope(
        address principal,
        bytes32 capabilityRoot,
        uint64 expiresAt,
        bytes calldata initData
    ) external returns (bytes32 id);

    /// @notice Read the full envelope. MUST revert on an unknown id.
    function getEnvelope(bytes32 id) external view returns (Envelope memory);

    /// @notice Read the current cursor commitment. MUST equal
    ///         getEnvelope(id).cursorRoot.
    function getCursor(bytes32 id) external view returns (bytes32);

    /// @notice Effective status: reports Expired once expiresAt is reached,
    ///         even while the stored status remains Active.
    function getStatus(bytes32 id) external view returns (Status);

    /// @notice True iff the effective status is Active.
    function isActive(bytes32 id) external view returns (bool);

    /// @notice Advance the cursor with a substrate-validated witness. MUST
    ///         revert on an invalid witness, unknown id, or non-Active
    ///         envelope, without modifying state. The advance MUST be atomic
    ///         with the substrate state change it represents.
    function advanceCursor(
        bytes32 id,
        bytes calldata witness
    ) external returns (bytes32 newCursor);

    /// @notice Transition the envelope's status. Authorization per transition
    ///         is implementation-defined and MUST be documented; the metered
    ///         party MUST NOT be able to exit Active to escape an unmet bound.
    function setStatus(bytes32 id, Status newStatus) external;
}
