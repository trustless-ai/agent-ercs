// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {ConfidentialStep, IConfidentialStep} from "../../../contracts/execution/ERC8301/IConfidentialStep.sol";
import {PolicyAction, PolicyActionLib} from "../../../contracts/verify/ERC8354/PolicyAction.sol";
import {Verdict, PolicyKind} from "../../../contracts/verify/ERC8354/IConfidentialPolicyVerdict.sol";

/// @notice Pins how a confidential ERC-8301 step maps into the canonical ERC-8354 action, and the
///         three bindings the composition depends on.
contract ConfidentialStepTest is Test {
    bytes32 constant DOMAIN = keccak256("domain-strict");
    bytes32 constant OTHER_DOMAIN = keccak256("domain-permissive");
    bytes32 constant RUN_A = keccak256("run-a");
    bytes32 constant RUN_B = keccak256("run-b");
    bytes32 constant REPLY_1 = keccak256("reply-1");
    bytes32 constant REPLY_2 = keccak256("reply-2");
    address constant WORKFLOW = 0x1111111111111111111111111111111111111111;
    uint256 constant AGENT_A = 42;
    uint256 constant AGENT_B = 43;

    function _commit(bytes32 domain, uint256 agentId, bytes32 run, bytes32 reply, uint256 nonce)
        internal
        view
        returns (bytes32)
    {
        return ConfidentialStep.actionCommitmentFor(domain, agentId, WORKFLOW, run, reply, nonce);
    }

    // ── It is the canonical commitment, not a second scheme ──────────────────

    /// The strongest property in this file. The commitment a confidential step produces must be
    /// exactly what `PolicyActionLib.commit` produces over the mapped fields, so an existing
    /// ERC-8354 proving program and Guard accept it unchanged.
    function test_commitment_is_the_canonical_policy_action_commitment() public view {
        PolicyAction memory a = PolicyAction({
            chainId: block.chainid,
            domainId: DOMAIN,
            agentId: AGENT_A,
            target: WORKFLOW,
            value: 0,
            callDataHash: ConfidentialStep.stepCallDataHash(RUN_A, REPLY_1),
            actionNonce: 7
        });
        assertEq(_commit(DOMAIN, AGENT_A, RUN_A, REPLY_1, 7), PolicyActionLib.commit(a));
    }

    /// A confidential step moves no value. If this ever changes, the commitment changes with it,
    /// which is the point of `value` being in the normative preimage.
    function test_step_carries_no_value() public view {
        PolicyAction memory a =
            ConfidentialStep.actionFor(DOMAIN, AGENT_A, WORKFLOW, RUN_A, REPLY_1, 1);
        assertEq(a.value, 0);
        assertEq(a.target, WORKFLOW);
        assertEq(a.agentId, AGENT_A);
        assertEq(a.domainId, DOMAIN);
    }

    // ── Binding 1: the domain the workflow trusts ────────────────────────────

    /// A verdict from a different domain produces a different commitment, so a permissive domain
    /// cannot gate a step meant for a stricter one. The interface additionally requires an
    /// explicit `policyDomain()` check, since the Guard validates whatever domain it is handed.
    function test_a_different_domain_cannot_produce_the_same_commitment() public view {
        assertTrue(
            _commit(DOMAIN, AGENT_A, RUN_A, REPLY_1, 1)
                != _commit(OTHER_DOMAIN, AGENT_A, RUN_A, REPLY_1, 1),
            "domain must separate commitments"
        );
    }

    // ── Binding 2: the agent that replied ────────────────────────────────────

    /// One agent's verdict must not gate another agent's reply. This binding lives in
    /// `PolicyAction.agentId`, inside the normative commitment, rather than in `Verdict.executor`.
    function test_a_different_agent_cannot_produce_the_same_commitment() public view {
        assertTrue(
            _commit(DOMAIN, AGENT_A, RUN_A, REPLY_1, 1)
                != _commit(DOMAIN, AGENT_B, RUN_A, REPLY_1, 1),
            "agent must separate commitments"
        );
    }

    // ── Binding 3: the exact step ────────────────────────────────────────────

    function test_commitment_is_scoped_to_the_run() public view {
        assertTrue(
            _commit(DOMAIN, AGENT_A, RUN_A, REPLY_1, 1)
                != _commit(DOMAIN, AGENT_A, RUN_B, REPLY_1, 1),
            "same reply in two runs must not share a commitment"
        );
    }

    function test_commitment_is_scoped_to_the_reply() public view {
        assertTrue(
            _commit(DOMAIN, AGENT_A, RUN_A, REPLY_1, 1)
                != _commit(DOMAIN, AGENT_A, RUN_A, REPLY_2, 1),
            "two replies in one run must not share a commitment"
        );
    }

    /// The nonce is monotonic per (domain, agent), so the same step replayed at a later nonce is a
    /// different action and needs its own verdict.
    function test_commitment_is_scoped_to_the_action_nonce() public view {
        assertTrue(
            _commit(DOMAIN, AGENT_A, RUN_A, REPLY_1, 1)
                != _commit(DOMAIN, AGENT_A, RUN_A, REPLY_1, 2),
            "nonce must separate commitments"
        );
    }

    function test_commitment_is_deterministic() public view {
        assertEq(
            _commit(DOMAIN, AGENT_A, RUN_A, REPLY_1, 1), _commit(DOMAIN, AGENT_A, RUN_A, REPLY_1, 1)
        );
    }

    // ── The step commitment occupies callDataHash safely ─────────────────────

    /// `callDataHash` normally holds `keccak256(callData)`. A step commitment shares that field,
    /// so it is domain-separated to keep it clear of real two-word calldata.
    function test_step_commitment_is_domain_separated_from_real_calldata() public pure {
        assertTrue(
            ConfidentialStep.stepCallDataHash(RUN_A, REPLY_1)
                != keccak256(abi.encode(RUN_A, REPLY_1)),
            "must not equal the hash of the same two words as plain calldata"
        );
    }

    function test_step_commitment_is_order_sensitive() public pure {
        assertTrue(
            ConfidentialStep.stepCallDataHash(RUN_A, REPLY_1)
                != ConfidentialStep.stepCallDataHash(REPLY_1, RUN_A),
            "argument order must matter"
        );
    }

    // ── Proof encoding ───────────────────────────────────────────────────────

    /// The payload carries the nonce as well, because the workflow cannot infer which nonce the
    /// commitment was built over.
    function test_proof_encoding_roundtrips() public view {
        Verdict memory v = Verdict({
            agentId: AGENT_A,
            domainId: DOMAIN,
            policyRoot: keccak256("root"),
            actionCommitment: _commit(DOMAIN, AGENT_A, RUN_A, REPLY_1, 9),
            executor: WORKFLOW,
            expiry: uint64(2_000_000_000),
            nullifier: keccak256("nullifier"),
            decision: 1,
            policyKind: PolicyKind.ALLOWED
        });

        (Verdict memory got, bytes memory proof, uint256 nonce) =
            ConfidentialStep.decodeProof(ConfidentialStep.encodeProof(v, hex"deadbeef", 9));

        assertEq(got.actionCommitment, v.actionCommitment);
        assertEq(got.executor, WORKFLOW, "the workflow is the executor, not the replier");
        assertEq(got.domainId, DOMAIN);
        assertEq(got.agentId, AGENT_A);
        assertEq(got.policyKind, PolicyKind.ALLOWED);
        assertEq(proof, hex"deadbeef");
        assertEq(nonce, 9);
    }

    // ── Refusal kinds survive the composition ────────────────────────────────

    function test_refusal_kinds_stay_distinguishable() public pure {
        assertTrue(PolicyKind.agreesWithDecision(PolicyKind.DENIED, 0));
        assertTrue(PolicyKind.agreesWithDecision(PolicyKind.NOT_PERMITTED, 0));
        assertTrue(PolicyKind.agreesWithDecision(PolicyKind.COULD_NOT_EVALUATE, 0));
        assertFalse(PolicyKind.agreesWithDecision(PolicyKind.ALLOWED, 0));
    }

    function test_only_allowed_agrees_with_an_allow_decision() public pure {
        assertTrue(PolicyKind.agreesWithDecision(PolicyKind.ALLOWED, 1));
        assertFalse(PolicyKind.agreesWithDecision(PolicyKind.DENIED, 1));
        assertFalse(PolicyKind.agreesWithDecision(PolicyKind.NOT_PERMITTED, 1));
        assertFalse(PolicyKind.agreesWithDecision(PolicyKind.COULD_NOT_EVALUATE, 1));
    }
}
