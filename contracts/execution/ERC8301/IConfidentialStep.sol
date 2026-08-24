// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import {Verdict} from "../../verify/ERC8354/IConfidentialPolicyVerdict.sol";
import {PolicyAction, PolicyActionLib} from "../../verify/ERC8354/PolicyAction.sol";

/// @title IConfidentialStep — an ERC-8301 workflow step gated by an ERC-8354 verdict
/// @notice A workflow stage whose reply carries no plaintext output. The gate is
///         satisfied by a confidential policy verdict: the action and the policy stay
///         hidden, while the fact that the action cleared the policy stays verifiable.
/// @dev    Part of ERC-8301 (AI Agent Execution), composed with ERC-8354
///         (Confidential Agent Policy Verdicts).
///
///         This path needs NO change to `IAgentWorkflow`. It rides the existing
///         `onAgentProve(replyHashes, proof)` seam, whose proof encoding the spec
///         already leaves verifier-specific, and fixes that encoding.
///
///         It also introduces no new commitment scheme. An earlier revision of this file
///         defined its own `actionCommitmentFor` hash, which would have required a second
///         proving program: `PolicyActionLib.commit` is normative, and a Guard cannot accept
///         anything else. A confidential step instead MAPS INTO the canonical `PolicyAction`
///         fields, so a domain that can issue verdicts today can gate a workflow today.

// ── Mapping a workflow step into the canonical action ────────────────────────

/// @notice How a confidential workflow step occupies the normative `PolicyAction` preimage.
/// @dev    Every field keeps its ERC-8354 meaning. Nothing is redefined.
///
///         | `PolicyAction` field | what a confidential step puts there |
///         |---|---|
///         | `chainId`      | `block.chainid`, unchanged replay separation |
///         | `domainId`     | the workflow's `policyDomain()` |
///         | `agentId`      | the ERC-8004 identity of the agent that replied |
///         | `target`       | the workflow contract, the call being authorised |
///         | `value`        | `0`, a workflow step moves no value |
///         | `callDataHash` | a domain-separated commitment to `(workflowRunId, replyHash)` |
///         | `actionNonce`  | monotonic per `(domain, agent)`, unchanged |
///
///         The workflow/run/reply binding lives in `callDataHash`, whose normative role is
///         already "what call is being authorised". The agent binding lives in `agentId`,
///         which is the field that carries it. Neither needs a new public input.
library ConfidentialStep {
    /// @notice Domain separator, so a step commitment can never collide with the hash of real
    ///         calldata that happens to be two words long.
    bytes32 internal constant STEP_TYPEHASH = keccak256("ERC8301.ConfidentialStep.v1");

    /// @notice The `callDataHash` a confidential step commits to.
    /// @dev    Scoped to the run as well as the reply. `replyHash` already covers
    ///         `workflowRunId`, but a verifier reading only the commitment should not have to
    ///         depend on that.
    function stepCallDataHash(bytes32 workflowRunId, bytes32 replyHash)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(STEP_TYPEHASH, workflowRunId, replyHash));
    }

    /// @notice Build the canonical `PolicyAction` for a confidential step.
    function actionFor(
        bytes32 domainId,
        uint256 agentId,
        address workflow,
        bytes32 workflowRunId,
        bytes32 replyHash,
        uint256 actionNonce
    ) internal view returns (PolicyAction memory) {
        return PolicyAction({
            chainId: block.chainid,
            domainId: domainId,
            agentId: agentId,
            target: workflow,
            value: 0,
            callDataHash: stepCallDataHash(workflowRunId, replyHash),
            actionNonce: actionNonce
        });
    }

    /// @notice The commitment a verdict MUST carry to gate this step, via the normative formula.
    function actionCommitmentFor(
        bytes32 domainId,
        uint256 agentId,
        address workflow,
        bytes32 workflowRunId,
        bytes32 replyHash,
        uint256 actionNonce
    ) internal view returns (bytes32) {
        return PolicyActionLib.commit(
            actionFor(domainId, agentId, workflow, workflowRunId, replyHash, actionNonce)
        );
    }

    /// @notice The `proof` payload for `IAgentWorkflow.onAgentProve` on a confidential step.
    /// @dev    `IAgentWorkflow` leaves this encoding verifier-specific and allows `onAgentProve` to
    ///         cover MORE THAN ONE `replyHash`. A verdict commits to exactly one action, so it
    ///         cannot span several replies. The payload therefore carries parallel arrays, one
    ///         entry per reply hash, validated and consumed individually.
    ///
    ///         An earlier revision carried a single verdict and silently assumed a single reply.
    ///         That assumption is not the interface's, so it does not belong here.
    function encodeProof(
        Verdict[] memory verdicts,
        bytes[] memory verdictProofs,
        uint256[] memory actionNonces
    ) internal pure returns (bytes memory) {
        return abi.encode(verdicts, verdictProofs, actionNonces);
    }

    function decodeProof(bytes memory payload)
        internal
        pure
        returns (Verdict[] memory verdicts, bytes[] memory verdictProofs, uint256[] memory actionNonces)
    {
        (verdicts, verdictProofs, actionNonces) =
            abi.decode(payload, (Verdict[], bytes[], uint256[]));
    }

    /// @notice Whether a decoded payload is well formed against the reply hashes it accompanies.
    /// @dev    Every reply gets its own verdict, proof and nonce. A payload that is shorter than
    ///         the reply list would leave replies ungated while the call still succeeds, which is
    ///         the failure this check exists to prevent.
    function payloadMatches(
        uint256 replyCount,
        Verdict[] memory verdicts,
        bytes[] memory verdictProofs,
        uint256[] memory actionNonces
    ) internal pure returns (bool) {
        return verdicts.length == replyCount && verdictProofs.length == replyCount
            && actionNonces.length == replyCount;
    }
}

// ── Interface ────────────────────────────────────────────────────────────────

interface IConfidentialStep {
    // ── Errors ───────────────────────────────────────────────────────────────

    /// @notice The verdict does not commit to this step under the canonical encoding.
    error ActionCommitmentMismatch(bytes32 expected, bytes32 actual);

    /// @notice The verdict was issued under a policy domain this workflow does not trust.
    /// @dev    The ERC-8354 Guard validates whichever domain the verdict supplies; it has no way
    ///         to know which domain this workflow intended. Without this check an ALLOW verdict
    ///         from another active but more permissive domain would gate a step meant to be held
    ///         to a stricter one.
    error PolicyDomainMismatch(bytes32 expected, bytes32 actual);

    /// @notice The verdict authorizes an agent other than the one that replied.
    /// @dev    Carried in `PolicyAction.agentId`, not in `Verdict.executor`. See
    ///         `verdictExecutor()` for why.
    error AgentMismatch(uint256 expected, uint256 actual);

    /// @notice The replying address is not authorized to act for this ERC-8004 agent.
    /// @dev    Putting `agentId` inside the commitment binds the verdict to an identity, but says
    ///         nothing about whether the address that actually replied controls that identity.
    ///         Without this check, one agent could submit a reply under another agent's id.
    error AgentNotAuthorized(uint256 agentId, address replier);

    /// @notice The payload does not carry one verdict, proof and nonce per reply hash.
    error PayloadLengthMismatch(uint256 replyCount, uint256 verdicts, uint256 proofs, uint256 nonces);

    /// @notice The action nonce is not the next one for this agent under this domain.
    /// @dev    ERC-8354 requires `actionNonce` to be strictly increasing per `(domain, agent)`.
    error NonceOutOfOrder(uint256 agentId, uint256 expected, uint256 actual);

    /// @notice The reply carried plaintext output on a stage declared confidential.
    error OutputNotWithheld(bytes32 replyHash);

    /// @notice The stage was gated by a refusal rather than an authorization.
    /// @dev    Carries `policyKind` rather than collapsing to "denied", so a consumer can tell
    ///         "a rule refused this" from "nothing authorized it" from "the policy could not be
    ///         evaluated".
    error StepRefused(bytes32 replyHash, uint8 policyKind);

    // ── Events ───────────────────────────────────────────────────────────────

    /// @notice A confidential step was settled by a verdict.
    event ConfidentialStepSettled(
        bytes32 indexed workflowRunId,
        bytes32 indexed replyHash,
        bytes32 indexed nullifier,
        uint8 policyKind
    );

    // ── Views ────────────────────────────────────────────────────────────────

    /// @notice The ERC-8354 policy domain this step gates on.
    /// @dev    A verdict whose `domainId` differs MUST be rejected with `PolicyDomainMismatch`.
    function policyDomain() external view returns (bytes32);

    /// @notice The ERC-8354 registry whose `consume` burns the verdict's nullifier.
    function verdictRegistry() external view returns (address);

    /// @notice The address a verdict for this workflow must name as its executor.
    /// @dev    This is the WORKFLOW CONTRACT, not the replying agent.
    ///
    ///         Direct `consume` requires `v.executor == msg.sender`, and on this path the caller
    ///         is the workflow, reached through `onAgentProve`. Naming the replier instead would
    ///         make the direct path unsatisfiable and force the relayed overload, which needs an
    ///         `executorAuth` signature the workflow has no way to obtain mid-transition.
    ///
    ///         Nothing is lost by this. The binding that matters, that one agent's verdict cannot
    ///         gate another agent's reply, is carried by `PolicyAction.agentId`, which is inside
    ///         the normative commitment. `executor` answers a different question: who may submit.
    ///         In a workflow the submitter is the workflow, and consumption stays atomic with the
    ///         transition rather than being a separable call some other party can front-run.
    function verdictExecutor() external view returns (address);

    /// @notice Whether `stage` is declared confidential for this workflow.
    /// @dev    Declared per stage so an observer can tell in advance which steps are expected to
    ///         withhold output. A stage that silently became confidential would be
    ///         indistinguishable from one that failed to produce output.
    function isConfidentialStage(uint8 stage) external view returns (bool);

    /// @notice The ERC-8004 Identity Registry this workflow resolves agent identities against.
    function identityRegistry() external view returns (address);

    /// @notice Whether `account` may act for `agentId`.
    /// @dev    ERC-8004's Identity Registry is an ERC-721, so authorization is already defined:
    ///         the token owner, an address approved for that token, or an operator approved for
    ///         all of the owner's tokens. This profile reuses those semantics rather than
    ///         inventing a delegation scheme of its own.
    ///
    ///         Note that `getAgentWallet(agentId)` is NOT the right source here. That is the
    ///         agent's payment wallet, which is a different question from who controls the
    ///         identity, and using it would authorize the wrong address.
    function isAuthorizedAgent(uint256 agentId, address account) external view returns (bool);

    /// @notice The next `actionNonce` for an agent under this workflow's domain.
    /// @dev    Monotonic per `(domain, agent)` as ERC-8354 requires, exposed so an issuer can
    ///         build a commitment the workflow will accept.
    ///
    ///         A confidential step MUST require the payload's `actionNonce` to equal this value at
    ///         the time of settlement, MUST increment it atomically once the verdict is consumed,
    ///         and MUST roll the increment back if the transition then fails. Otherwise a failed
    ///         transition burns a nonce and every later verdict for that agent is stale.
    function nextActionNonce(uint256 agentId) external view returns (uint256);

    /// @notice The commitment a verdict must carry to gate `replyHash` in `workflowRunId`.
    /// @dev    Computed with `PolicyActionLib.commit` over the canonical `PolicyAction`. There is
    ///         no second commitment scheme.
    function actionCommitmentFor(
        uint256 agentId,
        bytes32 workflowRunId,
        bytes32 replyHash,
        uint256 actionNonce
    ) external view returns (bytes32);

    /// @notice The verdict that settled a confidential step.
    /// @dev    MUST revert if `replyHash` is unknown. `settled` is false for a reply that was
    ///         anchored but never gated, which is the case `AgentReplyAnchored` makes observable.
    function stepVerdict(bytes32 replyHash)
        external
        view
        returns (bytes32 nullifier, uint8 policyKind, bool settled);
}
