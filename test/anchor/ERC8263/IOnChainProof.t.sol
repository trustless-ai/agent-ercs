// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../../../contracts/anchor/ERC8263/IOnChainProof.sol";

/// @dev Test-only event harness: emits the canonical event verbatim so the tests can
///      pin the topic layout. Deliberately implements NO write-time guards or storage —
///      this PR ships the ERC-8263 interface surface only, not a base or reference
///      implementation (canonical-form guards are specified in the ERC and enforced by
///      conforming implementations, not tested here).
contract EventHarness is IOnChainProof {
    function anchor(uint8 agentIdScheme, bytes32 agentId, bytes32 proofHash) external {
        emit AnchorProof(agentIdScheme, agentId, proofHash, msg.sender, "");
    }

    function anchorWithAux(
        uint8 agentIdScheme,
        bytes32 agentId,
        bytes32 proofHash,
        bytes calldata aux
    ) external {
        emit AnchorProof(agentIdScheme, agentId, proofHash, msg.sender, aux);
    }
}

contract IOnChainProofTest is Test {
    /// Spec constant: keccak256("AnchorProof(uint8,bytes32,bytes32,address,bytes)")
    bytes32 constant TOPIC0 =
        0x9fe832d83a52f83bd7d54181e4cc7ff8b4e227cc1d3a0144376894b5df6c23cc;

    EventHarness harness;

    function setUp() public {
        harness = new EventHarness();
    }

    /// Compilation guard: the interface compiles and a contract can implement it.
    function test_interfaceCompiles() public view {
        IOnChainProof iface = IOnChainProof(address(harness));
        assertTrue(address(iface) != address(0));
    }

    /// topic0 of the canonical event matches the constant printed in the spec.
    function test_topic0_matchesSpecConstant() public pure {
        assertEq(
            keccak256("AnchorProof(uint8,bytes32,bytes32,address,bytes)"),
            TOPIC0
        );
    }

    /// Entrypoint selectors are pinned to the canonical signatures.
    function test_selectors_matchCanonicalSignatures() public pure {
        assertEq(
            IOnChainProof.anchor.selector,
            bytes4(keccak256("anchor(uint8,bytes32,bytes32)"))
        );
        assertEq(
            IOnChainProof.anchorWithAux.selector,
            bytes4(keccak256("anchorWithAux(uint8,bytes32,bytes32,bytes)"))
        );
    }

    /// Indexed layout per spec: topic1 = agentId, topic2 = proofHash, topic3 = operator;
    /// data segment ABI-decodes as (uint8 agentIdScheme, bytes aux).
    function test_anchor_eventTopicLayout_emptyAux() public {
        bytes32 agentId = keccak256("agent");
        bytes32 proofHash = keccak256("proof");

        vm.recordLogs();
        harness.anchor(0x02, agentId, proofHash);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 1);
        assertEq(logs[0].topics.length, 4);
        assertEq(logs[0].topics[0], TOPIC0);
        assertEq(logs[0].topics[1], agentId);
        assertEq(logs[0].topics[2], proofHash);
        assertEq(logs[0].topics[3], bytes32(uint256(uint160(address(this)))));

        (uint8 scheme, bytes memory aux) = abi.decode(logs[0].data, (uint8, bytes));
        assertEq(scheme, 0x02);
        assertEq(aux.length, 0);
    }

    function test_anchorWithAux_eventTopicLayout_withAux() public {
        bytes32 agentId = keccak256("agent");
        bytes32 proofHash = keccak256("proof");
        bytes memory auxIn = hex"c0ffee";

        vm.recordLogs();
        harness.anchorWithAux(0x01, agentId, proofHash, auxIn);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 1);
        assertEq(logs[0].topics.length, 4);
        assertEq(logs[0].topics[0], TOPIC0);
        assertEq(logs[0].topics[1], agentId);
        assertEq(logs[0].topics[2], proofHash);
        assertEq(logs[0].topics[3], bytes32(uint256(uint160(address(this)))));

        (uint8 scheme, bytes memory aux) = abi.decode(logs[0].data, (uint8, bytes));
        assertEq(scheme, 0x01);
        assertEq(aux, auxIn);
    }
}
