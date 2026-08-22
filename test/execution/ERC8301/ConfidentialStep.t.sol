// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {
    ConfidentialStep, IConfidentialStep
} from "../../../contracts/execution/ERC8301/IConfidentialStep.sol";
import {PolicyAction, PolicyActionLib} from "../../../contracts/verify/ERC8354/PolicyAction.sol";
import {Verdict, PolicyKind} from "../../../contracts/verify/ERC8354/IConfidentialPolicyVerdict.sol";

/// @notice The ERC-8004 Identity Registry surface this profile relies on. It is an ERC-721, so
///         authorization is already defined and does not need a scheme of its own.
contract MockIdentityRegistry {
    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    mapping(uint256 => address) public getAgentWallet;

    function setOwner(uint256 agentId, address owner) external {
        ownerOf[agentId] = owner;
    }

    function setApproved(uint256 agentId, address account) external {
        getApproved[agentId] = account;
    }

    function setOperator(address owner, address operator, bool ok) external {
        isApprovedForAll[owner][operator] = ok;
    }

    function setAgentWallet(uint256 agentId, address wallet) external {
        getAgentWallet[agentId] = wallet;
    }
}

/// @notice A minimal implementation of the two rules that cannot live in a pure library: who may
///         act for an agent, and how the action nonce advances. Kept in the test tree because this
///         repository holds interfaces, not reference implementations.
contract StepHarness {
    MockIdentityRegistry public immutable registry;
    mapping(uint256 => uint256) public nextActionNonce;

    constructor(MockIdentityRegistry registry_) {
        registry = registry_;
    }

    function isAuthorizedAgent(uint256 agentId, address account) public view returns (bool) {
        address owner = registry.ownerOf(agentId);
        if (owner == address(0) || account == address(0)) return false;
        return account == owner || registry.getApproved(agentId) == account
            || registry.isApprovedForAll(owner, account);
    }

    /// Settle one confidential step. Reverts leave the nonce untouched, which is the rollback the
    /// profile requires: a failed transition must not burn a nonce and strand every later verdict.
    function settle(uint256 agentId, address replier, uint256 actionNonce, bool transitionSucceeds)
        external
    {
        if (!isAuthorizedAgent(agentId, replier)) {
            revert IConfidentialStep.AgentNotAuthorized(agentId, replier);
        }
        uint256 expected = nextActionNonce[agentId];
        if (actionNonce != expected) {
            revert IConfidentialStep.NonceOutOfOrder(agentId, expected, actionNonce);
        }
        nextActionNonce[agentId] = expected + 1;
        require(transitionSucceeds, "transition failed");
    }
}

/// @notice Pins how a confidential ERC-8301 step maps into the canonical ERC-8354 action, and the
///         bindings the composition depends on.
contract ConfidentialStepTest is Test {
    bytes32 constant DOMAIN = keccak256("domain-strict");
    bytes32 constant OTHER_DOMAIN = keccak256("domain-permissive");
    bytes32 constant RUN_A = keccak256("run-a");
    bytes32 constant RUN_B = keccak256("run-b");
    bytes32 constant REPLY_1 = keccak256("reply-1");
    bytes32 constant REPLY_2 = keccak256("reply-2");
    address constant WORKFLOW = 0x1111111111111111111111111111111111111111;
    address constant OWNER = 0x2222222222222222222222222222222222222222;
    address constant DELEGATE = 0x3333333333333333333333333333333333333333;
    address constant OPERATOR = 0x4444444444444444444444444444444444444444;
    address constant STRANGER = 0x5555555555555555555555555555555555555555;
    uint256 constant AGENT_A = 42;
    uint256 constant AGENT_B = 43;

    MockIdentityRegistry registry;
    StepHarness harness;

    function setUp() public {
        registry = new MockIdentityRegistry();
        harness = new StepHarness(registry);
        registry.setOwner(AGENT_A, OWNER);
        registry.setOwner(AGENT_B, STRANGER);
    }

    function _commit(bytes32 domain, uint256 agentId, bytes32 run, bytes32 reply, uint256 nonce)
        internal
        view
        returns (bytes32)
    {
        return ConfidentialStep.actionCommitmentFor(domain, agentId, WORKFLOW, run, reply, nonce);
    }

    // ── It is the canonical commitment, not a second scheme ──────────────────

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

    function test_step_carries_no_value() public view {
        PolicyAction memory a =
            ConfidentialStep.actionFor(DOMAIN, AGENT_A, WORKFLOW, RUN_A, REPLY_1, 1);
        assertEq(a.value, 0);
        assertEq(a.target, WORKFLOW);
    }

    // ── The commitment separates every field that matters ────────────────────

    function test_domain_separates_commitments() public view {
        assertTrue(
            _commit(DOMAIN, AGENT_A, RUN_A, REPLY_1, 1)
                != _commit(OTHER_DOMAIN, AGENT_A, RUN_A, REPLY_1, 1)
        );
    }

    function test_agent_separates_commitments() public view {
        assertTrue(
            _commit(DOMAIN, AGENT_A, RUN_A, REPLY_1, 1)
                != _commit(DOMAIN, AGENT_B, RUN_A, REPLY_1, 1)
        );
    }

    function test_run_separates_commitments() public view {
        assertTrue(
            _commit(DOMAIN, AGENT_A, RUN_A, REPLY_1, 1)
                != _commit(DOMAIN, AGENT_A, RUN_B, REPLY_1, 1)
        );
    }

    function test_reply_separates_commitments() public view {
        assertTrue(
            _commit(DOMAIN, AGENT_A, RUN_A, REPLY_1, 1)
                != _commit(DOMAIN, AGENT_A, RUN_A, REPLY_2, 1)
        );
    }

    function test_nonce_separates_commitments() public view {
        assertTrue(
            _commit(DOMAIN, AGENT_A, RUN_A, REPLY_1, 1)
                != _commit(DOMAIN, AGENT_A, RUN_A, REPLY_1, 2)
        );
    }

    function test_step_commitment_is_domain_separated_from_real_calldata() public pure {
        assertTrue(
            ConfidentialStep.stepCallDataHash(RUN_A, REPLY_1)
                != keccak256(abi.encode(RUN_A, REPLY_1))
        );
    }

    // ── One verdict per reply, never one verdict for many ────────────────────

    function _verdict(uint256 agentId, bytes32 reply, uint256 nonce)
        internal
        view
        returns (Verdict memory)
    {
        return Verdict({
            agentId: agentId,
            domainId: DOMAIN,
            policyRoot: keccak256("root"),
            actionCommitment: _commit(DOMAIN, agentId, RUN_A, reply, nonce),
            executor: WORKFLOW,
            expiry: uint64(2_000_000_000),
            nullifier: keccak256(abi.encode("nullifier", reply)),
            decision: 1,
            policyKind: PolicyKind.ALLOWED
        });
    }

    /// `onAgentProve` accepts an array of reply hashes, so the payload carries one entry per reply.
    function test_payload_roundtrips_for_two_replies() public view {
        Verdict[] memory vs = new Verdict[](2);
        vs[0] = _verdict(AGENT_A, REPLY_1, 0);
        vs[1] = _verdict(AGENT_A, REPLY_2, 1);
        bytes[] memory ps = new bytes[](2);
        ps[0] = hex"aa";
        ps[1] = hex"bb";
        uint256[] memory ns = new uint256[](2);
        ns[0] = 0;
        ns[1] = 1;

        (Verdict[] memory gotV, bytes[] memory gotP, uint256[] memory gotN) =
            ConfidentialStep.decodeProof(ConfidentialStep.encodeProof(vs, ps, ns));

        assertEq(gotV.length, 2);
        assertEq(gotV[0].actionCommitment, vs[0].actionCommitment);
        assertEq(gotV[1].actionCommitment, vs[1].actionCommitment);
        assertTrue(gotV[0].actionCommitment != gotV[1].actionCommitment, "one verdict per reply");
        assertEq(gotP[1], hex"bb");
        assertEq(gotN[1], 1);
    }

    /// A payload shorter than the reply list would leave replies ungated while the call succeeds.
    function test_short_payload_does_not_match_the_reply_count() public view {
        Verdict[] memory vs = new Verdict[](1);
        vs[0] = _verdict(AGENT_A, REPLY_1, 0);
        bytes[] memory ps = new bytes[](1);
        uint256[] memory ns = new uint256[](1);

        assertTrue(ConfidentialStep.payloadMatches(1, vs, ps, ns), "one reply, one entry");
        assertFalse(ConfidentialStep.payloadMatches(2, vs, ps, ns), "two replies, one entry");
    }

    function test_ragged_payload_does_not_match() public view {
        Verdict[] memory vs = new Verdict[](2);
        vs[0] = _verdict(AGENT_A, REPLY_1, 0);
        vs[1] = _verdict(AGENT_A, REPLY_2, 1);
        bytes[] memory ps = new bytes[](2);
        uint256[] memory ns = new uint256[](1);
        assertFalse(ConfidentialStep.payloadMatches(2, vs, ps, ns), "nonces short");
    }

    // ── agentId must belong to the address that replied ──────────────────────

    function test_owner_may_act_for_its_agent() public view {
        assertTrue(harness.isAuthorizedAgent(AGENT_A, OWNER));
    }

    function test_token_approval_delegates() public {
        registry.setApproved(AGENT_A, DELEGATE);
        assertTrue(harness.isAuthorizedAgent(AGENT_A, DELEGATE));
    }

    function test_operator_approval_delegates() public {
        registry.setOperator(OWNER, OPERATOR, true);
        assertTrue(harness.isAuthorizedAgent(AGENT_A, OPERATOR));
    }

    /// The binding Jimmy asked for: one address replying under another agent's identity.
    function test_stranger_cannot_act_for_another_agent() public {
        assertFalse(harness.isAuthorizedAgent(AGENT_A, STRANGER));
        vm.expectRevert(
            abi.encodeWithSelector(
                IConfidentialStep.AgentNotAuthorized.selector, AGENT_A, STRANGER
            )
        );
        harness.settle(AGENT_A, STRANGER, 0, true);
    }

    /// The payment wallet is not the control address. Authorizing it would authorize the wrong
    /// account, which is easy to do by reaching for the first registry field that looks relevant.
    function test_payment_wallet_is_not_authorization() public {
        registry.setAgentWallet(AGENT_A, STRANGER);
        assertFalse(harness.isAuthorizedAgent(AGENT_A, STRANGER), "wallet must not authorize");
    }

    // ── Nonce ordering ───────────────────────────────────────────────────────

    function test_nonce_must_be_the_next_one() public {
        harness.settle(AGENT_A, OWNER, 0, true);
        assertEq(harness.nextActionNonce(AGENT_A), 1);
        harness.settle(AGENT_A, OWNER, 1, true);
        assertEq(harness.nextActionNonce(AGENT_A), 2);
    }

    function test_out_of_order_nonce_is_refused() public {
        vm.expectRevert(
            abi.encodeWithSelector(IConfidentialStep.NonceOutOfOrder.selector, AGENT_A, 0, 5)
        );
        harness.settle(AGENT_A, OWNER, 5, true);
    }

    function test_repeated_nonce_is_refused() public {
        harness.settle(AGENT_A, OWNER, 0, true);
        vm.expectRevert(
            abi.encodeWithSelector(IConfidentialStep.NonceOutOfOrder.selector, AGENT_A, 1, 0)
        );
        harness.settle(AGENT_A, OWNER, 0, true);
    }

    /// A failed transition must not burn a nonce. Otherwise every verdict already issued for that
    /// agent is stale and has to be reissued.
    function test_failed_transition_rolls_the_nonce_back() public {
        vm.expectRevert(bytes("transition failed"));
        harness.settle(AGENT_A, OWNER, 0, false);
        assertEq(harness.nextActionNonce(AGENT_A), 0, "nonce untouched after a failed transition");
        harness.settle(AGENT_A, OWNER, 0, true);
    }

    /// Nonces are per agent, so one agent's activity never invalidates another's verdicts.
    function test_nonces_are_per_agent() public {
        harness.settle(AGENT_A, OWNER, 0, true);
        assertEq(harness.nextActionNonce(AGENT_B), 0);
        harness.settle(AGENT_B, STRANGER, 0, true);
        assertEq(harness.nextActionNonce(AGENT_A), 1);
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
    }
}
