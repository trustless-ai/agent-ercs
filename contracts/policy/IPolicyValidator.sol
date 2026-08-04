// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IPolicyValidator — Agent Policy Enforcement
/// @notice Programmable trust rules between identity verification and execution.
///         An agent that has passed identity checks (ERC-8004) and been dispatched
///         a task (ERC-8301) MAY still be blocked by a policy validator before
///         the action reaches settlement.
/// @dev    Composition point in the trustless-ai boundary chain:
///         identity → [policy] → dispatch → provenance → verify → anchor →
///         eligibility → settlement → reputation.
///         A compliant policy validator evaluates an action and returns a
///         Decision that downstream callers MUST respect.
interface IPolicyValidator {
    /// @notice The outcome of a policy evaluation.
    /// @dev Pass = 0, Block = 1, PendingHITL = 2 (human-in-the-loop required).
    enum Decision {
        Pass,
        Block,
        PendingHITL
    }

    /// @notice Evaluate whether an agent's intended action is allowed.
    /// @param agentId   The ERC-8004 agent identifier (tokenId from IIdentityRegistry).
    /// @param action    Encoded action payload (e.g. abi.encode(target, value, data)).
    /// @param intent    Human-readable intent description for audit trail.
    /// @param chainId   The chain on which the action will be executed (EIP-155 chain ID).
    /// @return decision The policy decision — Pass, Block, or PendingHITL.
    /// @return reason   Human-readable explanation for the decision.
    /// @return evidence Opaque bytes carrying cryptographic proof of evaluation
    ///                  (e.g. WYRIWE commitment hash, simulation result hash).
    function evaluate(
        uint256 agentId,
        bytes calldata action,
        string calldata intent,
        uint256 chainId
    )
        external
        returns (Decision decision, string memory reason, bytes memory evidence);

    /// @notice Emitted when a policy evaluation is produced.
    /// @param agentId      The ERC-8004 agent identifier.
    /// @param decision     0 = Pass, 1 = Block, 2 = PendingHITL.
    /// @param reason       Human-readable explanation.
    /// @param evidenceHash keccak256 of the evidence bytes produced by evaluate().
    ///                     Third parties can recompute this hash from the evidence
    ///                     to verify the evaluation independently.
    event PolicyEvaluated(
        uint256 indexed agentId,
        uint8   indexed decision,
        string           reason,
        bytes32 indexed evidenceHash
    );
}

/// @title IPolicyRule — Composable Policy Rule
/// @notice Individual policy rule that can be composed into a PolicyValidator.
///         Each rule answers one question: is this action allowed?
/// @dev    Rules are composable: a PolicyValidator evaluates an ordered list
///         of rules and returns the first non-Pass decision.
interface IPolicyRule {
    /// @notice Check whether this rule permits the action.
    /// @param agentId The ERC-8004 agent identifier.
    /// @param action  Encoded action payload.
    /// @param chainId The execution chain ID.
    /// @return allowed True if the action passes this rule.
    /// @return reason  Explanation if not allowed.
    function check(
        uint256 agentId,
        bytes calldata action,
        uint256 chainId
    )
        external
        view
        returns (bool allowed, string memory reason);
}
