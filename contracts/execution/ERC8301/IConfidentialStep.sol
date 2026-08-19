// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import {Verdict} from "../../verify/ERC8354/IConfidentialPolicyVerdict.sol";

/// @title IConfidentialStep — an ERC-8301 workflow step gated by an ERC-8354 verdict
/// @notice A workflow stage whose reply carries no plaintext output. The gate is
///         satisfied by a confidential policy verdict: the action and the policy stay
///         hidden, while the fact that the action cleared the policy stays verifiable.
/// @dev    Part of ERC-8301 (AI Agent Execution), composed with ERC-8354
///         (Confidential Agent Policy Verdicts).
///
///         This path needs NO change to `IAgentWorkflow`. It rides the existing
///         `onAgentProve(replyHashes, proof)` seam, whose proof encoding the spec
///         already leaves verifier-specific. What follows fixes that encoding and the
///         two bindings that make the composition sound.
///
///         It also needs no change to the ERC-8354 proving program. Both bindings use
///         fields that are already public inputs of every verdict, so a domain that
///         can issue verdicts today can gate a workflow today.

// ── Binding ──────────────────────────────────────────────────────────────────

/// @notice Derivation of the action commitment a verdict MUST carry to gate a reply.
/// @dev    The two bindings this library and `IConfidentialStep` enforce:
///
///         1. `v.actionCommitment == actionCommitmentFor(workflowRunId, replyHash)`.
///            Without it, a verdict issued for one action could gate an unrelated
///            reply. Scoping by `workflowRunId` as well as `replyHash` means a verdict
///            cannot be lifted between runs even if two runs produce an identical
///            reply, which they can: `replyHash` covers `workflowRunId`, but a caller
///            reading only `actionCommitment` should not have to rely on that.
///
///         2. `v.executor == reply.replier`. Without it, agent A's verdict could gate
///            agent B's reply. `IAgentWorkflow` already requires `reply.replier` to
///            equal `msg.sender` at submission, so this binds the verdict to the agent
///            that actually answered.
///
///         Neither binding needs a new public input. `actionCommitment` and `executor`
///         are already fields of `Verdict`, so the composition is a constraint on what
///         those fields must hold, not an extension of the standard.
library ConfidentialStep {
    /// @notice Domain separator, so a commitment built for a workflow step can never
    ///         collide with an action commitment built for any other ERC-8354 consumer.
    bytes32 internal constant ACTION_COMMITMENT_DOMAIN =
        keccak256("ERC8301.ConfidentialStep.actionCommitment.v1");

    /// @notice The commitment a verdict MUST carry to gate `replyHash` in `workflowRunId`.
    function actionCommitmentFor(bytes32 workflowRunId, bytes32 replyHash)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(ACTION_COMMITMENT_DOMAIN, workflowRunId, replyHash));
    }

    /// @notice The `proof` payload for `IAgentWorkflow.onAgentProve` on a confidential step.
    /// @dev    `IAgentWorkflow` leaves this encoding verifier-specific. A confidential step
    ///         fixes it to the verdict plus the ERC-8354 proof bytes, so a verifier can
    ///         decode without an out-of-band agreement.
    function encodeProof(Verdict memory v, bytes memory verdictProof)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(v, verdictProof);
    }

    function decodeProof(bytes memory payload)
        internal
        pure
        returns (Verdict memory v, bytes memory verdictProof)
    {
        (v, verdictProof) = abi.decode(payload, (Verdict, bytes));
    }
}

// ── Interface ────────────────────────────────────────────────────────────────

interface IConfidentialStep {
    // ── Errors ───────────────────────────────────────────────────────────────

    /// @notice The verdict does not commit to this reply in this run.
    error ActionCommitmentMismatch(bytes32 expected, bytes32 actual);

    /// @notice The verdict authorizes a different address than the agent that replied.
    error ReplierMismatch(address expected, address actual);

    /// @notice The reply carried plaintext output on a stage declared confidential.
    /// @dev    A confidential step that also publishes its output is not confidential.
    ///         Rejecting it here keeps the stage's claim honest rather than advisory.
    error OutputNotWithheld(bytes32 replyHash);

    /// @notice The stage was gated by a refusal rather than an authorization.
    /// @dev    Carries `policyKind` rather than collapsing to "denied", so a consumer
    ///         can tell "a rule refused this" from "nothing authorized it" from
    ///         "the policy could not be evaluated".
    error StepRefused(bytes32 replyHash, uint8 policyKind);

    // ── Events ───────────────────────────────────────────────────────────────

    /// @notice A confidential step was settled by a verdict.
    /// @dev    `nullifier` is the content-addressed pointer from the observable event
    ///         back to the exact verdict bytes, which is what `getAgentReply`'s
    ///         `verificationDigest` should return for a confidential step.
    event ConfidentialStepSettled(
        bytes32 indexed workflowRunId,
        bytes32 indexed replyHash,
        bytes32 indexed nullifier,
        uint8           policyKind
    );

    // ── Views ────────────────────────────────────────────────────────────────

    /// @notice The ERC-8354 policy domain this step gates on.
    function policyDomain() external view returns (bytes32);

    /// @notice The ERC-8354 registry whose `consume` burns the verdict's nullifier.
    function verdictRegistry() external view returns (address);

    /// @notice Whether `stage` is declared confidential for this workflow.
    /// @dev    Declared per stage, not per reply, so an observer can tell in advance
    ///         which steps are expected to withhold output. A stage that silently
    ///         became confidential would be indistinguishable from one that failed
    ///         to produce output.
    function isConfidentialStage(uint8 stage) external view returns (bool);

    /// @notice The commitment a verdict must carry to gate `replyHash` in `workflowRunId`.
    function actionCommitmentFor(bytes32 workflowRunId, bytes32 replyHash)
        external
        view
        returns (bytes32);

    /// @notice The verdict that settled a confidential step.
    /// @dev    MUST revert if `replyHash` is unknown. `settled` is false for a reply
    ///         that was anchored but never gated, which is the case `AgentReplyAnchored`
    ///         exists to make observable.
    function stepVerdict(bytes32 replyHash)
        external
        view
        returns (bytes32 nullifier, uint8 policyKind, bool settled);
}
