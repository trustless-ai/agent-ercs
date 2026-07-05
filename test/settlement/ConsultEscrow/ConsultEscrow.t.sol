// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/settlement/ConsultEscrow/ConsultEscrow.sol";
import "../../../contracts/settlement/ConsultEscrow/IConsultEscrow.sol";

contract ConsultEscrowTest is Test {
    ConsultEscrow escrow;
    uint256 constant attestorPk = 0xA11CE;
    address attestor;
    address consumer = address(0xC0);
    address payable provider = payable(address(0xB0));

    function setUp() public {
        escrow = new ConsultEscrow();
        attestor = vm.addr(attestorPk);
        vm.deal(consumer, 10 ether);
    }

    function _open(bytes32 jobId, uint256 amount) internal {
        vm.prank(consumer);
        escrow.open{value: amount}(jobId, provider, attestor, block.timestamp + 1 days);
    }

    // Attestor signs the commitment = keccak256(abi.encode(jobId, resultHash)) as an EIP-191 message.
    function _sign(uint256 pk, bytes32 jobId, bytes32 resultHash) internal pure returns (bytes memory) {
        bytes32 commitment = keccak256(abi.encode(jobId, resultHash));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", commitment));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, ethHash);
        return abi.encodePacked(r, s, v);
    }

    function test_release_happyPath() public {
        bytes32 jobId = keccak256("job1");
        bytes32 resultHash = keccak256("result1");
        _open(jobId, 1 ether);
        uint256 bal = provider.balance;
        escrow.release(jobId, resultHash, _sign(attestorPk, jobId, resultHash));
        assertEq(provider.balance, bal + 1 ether);
        (, , , , , IConsultEscrow.Status status) = escrow.jobs(jobId);
        assertEq(uint256(status), uint256(IConsultEscrow.Status.Released));
    }

    function test_release_wrongSigner_reverts() public {
        bytes32 jobId = keccak256("job1");
        bytes32 resultHash = keccak256("result1");
        _open(jobId, 1 ether);
        vm.expectRevert("bad attestor sig");
        escrow.release(jobId, resultHash, _sign(0xBAD, jobId, resultHash));
    }

    /// @dev THE FIX (Fede's finding): a signature valid for jobA's (jobA, resultHash)
    ///      commitment must NOT release jobB, even with an identical attestor + resultHash,
    ///      because release() recomputes the commitment from jobId on-chain.
    function test_signature_isBoundToJobId() public {
        bytes32 jobA = keccak256("jobA");
        bytes32 jobB = keccak256("jobB");
        bytes32 resultHash = keccak256("sameResult");
        _open(jobA, 1 ether);
        _open(jobB, 1 ether);

        bytes memory sigForA = _sign(attestorPk, jobA, resultHash);
        escrow.release(jobA, resultHash, sigForA);          // A releases fine

        vm.expectRevert("bad attestor sig");                // same sig cannot release B
        escrow.release(jobB, resultHash, sigForA);
    }

    function test_refund_afterDeadline() public {
        bytes32 jobId = keccak256("job1");
        _open(jobId, 1 ether);
        vm.warp(block.timestamp + 2 days);
        uint256 bal = consumer.balance;
        escrow.refund(jobId);
        assertEq(consumer.balance, bal + 1 ether);
    }

    function test_refund_beforeDeadline_reverts() public {
        bytes32 jobId = keccak256("job1");
        _open(jobId, 1 ether);
        vm.expectRevert("before deadline");
        escrow.refund(jobId);
    }

    function test_release_notOpen_reverts() public {
        bytes32 jobId = keccak256("job1");
        bytes32 resultHash = keccak256("r");
        _open(jobId, 1 ether);
        escrow.release(jobId, resultHash, _sign(attestorPk, jobId, resultHash));
        vm.expectRevert("not open");
        escrow.release(jobId, resultHash, _sign(attestorPk, jobId, resultHash));
    }
}
