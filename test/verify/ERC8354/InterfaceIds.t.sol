// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IConfidentialPolicyVerdict, Verdict, PolicyKind} from "../../../contracts/verify/ERC8354/IConfidentialPolicyVerdict.sol";
import {IPolicyDomainRegistry} from "../../../contracts/verify/ERC8354/IPolicyDomainRegistry.sol";

/// @notice Pins the frozen ERC-8354 identifiers and the return-ABI shapes a
///         selector cannot protect. `Domain` and `Verdict` appear only as a
///         return type and a calldata argument, so inserting, removing, or
///         reordering a field leaves every selector untouched and a clean
///         compile proves nothing. These tests fail instead.
contract InterfaceIdsTest is Test {
    function test_confidentialPolicyVerdict_interfaceId_frozen() public pure {
        assertEq(type(IConfidentialPolicyVerdict).interfaceId, bytes4(0xd6da8150));
    }

    /// @dev Named-field construction is order-independent, so it alone would not
    ///      notice two same-typed fields swapping places. Comparing the whole
    ///      encoding against the expected word sequence pins the order too.
    function test_domain_layout_frozen() public pure {
        IPolicyDomainRegistry.Domain memory d = IPolicyDomainRegistry.Domain({
            registrar: address(0x1),
            identityRegistry: address(0x2),
            verifier: address(0x3),
            programKey: bytes32(uint256(4)),
            maxRootAge: 5,
            active: true
        });
        assertEq(
            abi.encode(d),
            abi.encode(
                uint256(0x1), uint256(0x2), uint256(0x3), uint256(4), uint256(5), uint256(1)
            )
        );
        assertEq(abi.encode(d).length, 6 * 32);
    }

    function test_verdict_layout_frozen() public pure {
        Verdict memory v = Verdict({
            agentId: 1,
            domainId: bytes32(uint256(2)),
            policyRoot: bytes32(uint256(3)),
            actionCommitment: bytes32(uint256(4)),
            executor: address(0x5),
            expiry: 6,
            nullifier: bytes32(uint256(7)),
            decision: 8,
            policyKind: PolicyKind.DENIED
        });
        assertEq(
            abi.encode(v),
            abi.encode(
                uint256(1), uint256(2), uint256(3), uint256(4),
                uint256(5), uint256(6), uint256(7), uint256(8), uint256(1)
            )
        );
        assertEq(abi.encode(v).length, 9 * 32);
    }

    function test_policyKind_constants_frozen() public pure {
        assertEq(PolicyKind.ALLOWED, 0);
        assertEq(PolicyKind.DENIED, 1);
        assertEq(PolicyKind.NOT_PERMITTED, 2);
        assertEq(PolicyKind.COULD_NOT_EVALUATE, 3);
    }

    function test_policyKind_agreesWithDecision() public pure {
        assertTrue(PolicyKind.agreesWithDecision(PolicyKind.ALLOWED, 1));
        assertFalse(PolicyKind.agreesWithDecision(PolicyKind.DENIED, 1));
        assertTrue(PolicyKind.agreesWithDecision(PolicyKind.DENIED, 0));
        assertTrue(PolicyKind.agreesWithDecision(PolicyKind.NOT_PERMITTED, 0));
        assertTrue(PolicyKind.agreesWithDecision(PolicyKind.COULD_NOT_EVALUATE, 0));
        assertFalse(PolicyKind.agreesWithDecision(PolicyKind.ALLOWED, 0));
    }
}
