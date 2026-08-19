// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {ConfidentialStep} from "../../../contracts/execution/ERC8301/IConfidentialStep.sol";
import {Verdict, PolicyKind} from "../../../contracts/verify/ERC8354/IConfidentialPolicyVerdict.sol";

/// @notice Pins the two bindings a confidential ERC-8301 step relies on, and the
///         proof encoding that lets a verifier decode `onAgentProve` without an
///         out-of-band agreement.
contract ConfidentialStepTest is Test {
    bytes32 constant RUN_A = keccak256("run-a");
    bytes32 constant RUN_B = keccak256("run-b");
    bytes32 constant REPLY_1 = keccak256("reply-1");
    bytes32 constant REPLY_2 = keccak256("reply-2");

    function _verdict(bytes32 actionCommitment, address executor, uint8 decision, uint8 kind)
        internal
        pure
        returns (Verdict memory v)
    {
        v = Verdict({
            agentId: 42,
            domainId: keccak256("domain"),
            policyRoot: keccak256("root"),
            actionCommitment: actionCommitment,
            executor: executor,
            expiry: uint64(2_000_000_000),
            nullifier: keccak256("nullifier"),
            decision: decision,
            policyKind: kind
        });
    }

    // ── Binding 1: the commitment is scoped to both the run and the reply ─────

    /// The same reply in two different runs must not share a commitment, otherwise a
    /// verdict issued for one run could gate the other.
    function test_commitment_is_scoped_to_the_run() public pure {
        assertTrue(
            ConfidentialStep.actionCommitmentFor(RUN_A, REPLY_1)
                != ConfidentialStep.actionCommitmentFor(RUN_B, REPLY_1),
            "same reply in two runs must not share a commitment"
        );
    }

    /// Two replies in the same run must not share a commitment either.
    function test_commitment_is_scoped_to_the_reply() public pure {
        assertTrue(
            ConfidentialStep.actionCommitmentFor(RUN_A, REPLY_1)
                != ConfidentialStep.actionCommitmentFor(RUN_A, REPLY_2),
            "two replies in one run must not share a commitment"
        );
    }

    function test_commitment_is_deterministic() public pure {
        assertEq(
            ConfidentialStep.actionCommitmentFor(RUN_A, REPLY_1),
            ConfidentialStep.actionCommitmentFor(RUN_A, REPLY_1)
        );
    }

    /// The domain separator must actually enter the preimage. Without it, a bare
    /// keccak256(run, reply) could collide with an action commitment built by any
    /// other ERC-8354 consumer that happens to hash two words the same way.
    function test_commitment_is_domain_separated() public pure {
        assertTrue(
            ConfidentialStep.actionCommitmentFor(RUN_A, REPLY_1)
                != keccak256(abi.encode(RUN_A, REPLY_1)),
            "commitment must not equal the undomained hash of its inputs"
        );
    }

    /// Swapping the two arguments must change the result, or a reply hash could be
    /// passed as a run id and still verify.
    function test_commitment_is_order_sensitive() public pure {
        assertTrue(
            ConfidentialStep.actionCommitmentFor(RUN_A, REPLY_1)
                != ConfidentialStep.actionCommitmentFor(REPLY_1, RUN_A),
            "argument order must matter"
        );
    }

    // ── Proof encoding ───────────────────────────────────────────────────────

    /// A verifier decoding an `onAgentProve` payload must recover the verdict exactly,
    /// including `policyKind`, which is what keeps the three refusal kinds separable.
    function test_proof_encoding_roundtrips() public pure {
        bytes32 ac = ConfidentialStep.actionCommitmentFor(RUN_A, REPLY_1);
        Verdict memory v = _verdict(ac, address(0xA11CE), 1, PolicyKind.ALLOWED);
        bytes memory zk = hex"deadbeef";

        (Verdict memory got, bytes memory gotProof) =
            ConfidentialStep.decodeProof(ConfidentialStep.encodeProof(v, zk));

        assertEq(got.actionCommitment, ac);
        assertEq(got.executor, address(0xA11CE));
        assertEq(got.agentId, 42);
        assertEq(got.nullifier, v.nullifier);
        assertEq(got.decision, 1);
        assertEq(got.policyKind, PolicyKind.ALLOWED);
        assertEq(gotProof, zk);
    }

    /// An empty ZK proof must still decode rather than revert. Rejecting a malformed
    /// proof is the verifier's job and belongs after decoding, so that a caller gets
    /// InvalidProof rather than a decode failure.
    function test_proof_encoding_roundtrips_with_empty_proof() public pure {
        Verdict memory v = _verdict(bytes32(0), address(0), 0, PolicyKind.DENIED);
        (Verdict memory got, bytes memory gotProof) =
            ConfidentialStep.decodeProof(ConfidentialStep.encodeProof(v, ""));
        assertEq(gotProof.length, 0);
        assertEq(got.policyKind, PolicyKind.DENIED);
    }

    // ── Refusal kinds survive the composition ────────────────────────────────

    /// The point of carrying policyKind through the step is that a refusal keeps its
    /// kind. All three refusal kinds are valid against decision = 0, and ALLOWED is not.
    function test_refusal_kinds_stay_distinguishable() public pure {
        assertTrue(PolicyKind.agreesWithDecision(PolicyKind.DENIED, 0));
        assertTrue(PolicyKind.agreesWithDecision(PolicyKind.NOT_PERMITTED, 0));
        assertTrue(PolicyKind.agreesWithDecision(PolicyKind.COULD_NOT_EVALUATE, 0));
        assertFalse(PolicyKind.agreesWithDecision(PolicyKind.ALLOWED, 0));
    }

    /// An ALLOW verdict is the only one that may gate a step open.
    function test_only_allowed_agrees_with_an_allow_decision() public pure {
        assertTrue(PolicyKind.agreesWithDecision(PolicyKind.ALLOWED, 1));
        assertFalse(PolicyKind.agreesWithDecision(PolicyKind.DENIED, 1));
        assertFalse(PolicyKind.agreesWithDecision(PolicyKind.NOT_PERMITTED, 1));
        assertFalse(PolicyKind.agreesWithDecision(PolicyKind.COULD_NOT_EVALUATE, 1));
    }
}
