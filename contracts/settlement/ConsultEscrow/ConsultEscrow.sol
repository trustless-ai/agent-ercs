// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IConsultEscrow} from "./IConsultEscrow.sol";

/// @title ConsultEscrow — trustless pay-on-delivery for agent consultations
/// @notice A consumer locks payment for a consultation; it releases to the provider
///         only when the named attestor (the agent's signer / a verifier) signs the
///         result's WYRIWE commitment, or refunds the consumer after a deadline if no
///         valid result is delivered. No valid signed result -> no payment.
/// @dev    Base implementation. Deployed and Etherscan-verified on Ethereum mainnet at
///         0x7057fbA75Ca88B8eF43564be3244bdd7163De04D. Every state transition is
///         recomputable from public data; the release commitment recompute is pinned as
///         recompute-kit vector `settlement-proof-consult` (recipe `8203/settlement-proof`).
///         Checks-effects-interactions ordered; the security of `release` rests entirely
///         on the attestor signature over the on-chain-recomputed, job-bound commitment.
contract ConsultEscrow is IConsultEscrow {
    mapping(bytes32 => Job) public jobs;

    /// @inheritdoc IConsultEscrow
    function open(bytes32 jobId, address provider, address attestor, uint256 deadline) external payable {
        require(jobs[jobId].status == Status.None, "job exists");
        require(msg.value > 0, "no payment");
        require(provider != address(0) && attestor != address(0), "zero addr");
        require(deadline > block.timestamp, "deadline past");
        jobs[jobId] = Job(msg.sender, provider, attestor, msg.value, deadline, Status.Open);
        emit Opened(jobId, msg.sender, provider, attestor, msg.value, deadline);
    }

    /// @inheritdoc IConsultEscrow
    /// @dev The commitment is recomputed from `jobId` ON-CHAIN, so a valid signature is
    ///      bound to this exact job — it cannot be replayed against another open job that
    ///      happens to share the same result hash (see test `test_signature_isBoundToJobId`).
    function release(bytes32 jobId, bytes32 resultHash, bytes calldata signature) external {
        Job storage j = jobs[jobId];
        require(j.status == Status.Open, "not open");
        bytes32 commitmentHash = keccak256(abi.encode(jobId, resultHash));
        require(_recover(commitmentHash, signature) == j.attestor, "bad attestor sig");
        j.status = Status.Released;
        uint256 amt = j.amount;
        (bool ok, ) = j.provider.call{value: amt}("");
        require(ok, "pay failed");
        emit Released(jobId, resultHash, commitmentHash, j.provider, amt);
    }

    /// @inheritdoc IConsultEscrow
    function refund(bytes32 jobId) external {
        Job storage j = jobs[jobId];
        require(j.status == Status.Open, "not open");
        require(block.timestamp >= j.deadline, "before deadline");
        j.status = Status.Refunded;
        uint256 amt = j.amount;
        (bool ok, ) = j.consumer.call{value: amt}("");
        require(ok, "refund failed");
        emit Refunded(jobId, j.consumer, amt);
    }

    /// @dev EIP-191 personal_sign recovery of the attestor over `hash`.
    function _recover(bytes32 hash, bytes calldata sig) internal pure returns (address) {
        require(sig.length == 65, "bad sig len");
        bytes32 r; bytes32 s; uint8 v;
        assembly {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 32))
            v := byte(0, calldataload(add(sig.offset, 64)))
        }
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
        return ecrecover(ethHash, v, r, s);
    }
}
