// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IConsultEscrow — pay-on-delivery settlement for agent consultations
/// @notice A consumer locks payment for a consultation; the funds release to the
///         provider only when the named attestor signs the result's commitment, or
///         refund to the consumer after a deadline if no valid result is delivered.
///         Settlement custody is fully on-chain — the consumer never trusts a
///         platform-held balance, and no valid signed result means no payment.
/// @dev    The release commitment is `keccak256(abi.encode(jobId, resultHash))` and is
///         recomputed from `jobId` ON-CHAIN, so an attestor signature is bound to the
///         exact job (see `release`). This is the recomputable "outcome attestation"
///         leg of the agent-standards settlement link — the release event is fully
///         re-derivable from public data (recompute-kit recipe `8203/settlement-proof`).
interface IConsultEscrow {
    /// @notice Lifecycle status of a job's escrow.
    enum Status { None, Open, Released, Refunded }

    /// @notice The escrowed consultation job.
    /// @param consumer the payer; refund recipient after a lapsed deadline
    /// @param provider paid on a valid signed release (the agent's wallet)
    /// @param attestor key whose signature over the commitment authorizes release
    /// @param amount   locked ETH, in wei
    /// @param deadline unix timestamp after which the consumer may refund
    /// @param status   current lifecycle state
    struct Job {
        address consumer;
        address provider;
        address attestor;
        uint256 amount;
        uint256 deadline;
        Status  status;
    }

    /// @notice Emitted when a consumer opens and funds a job.
    event Opened(bytes32 indexed jobId, address indexed consumer, address indexed provider, address attestor, uint256 amount, uint256 deadline);
    /// @notice Emitted on a valid attestor-signed release to the provider.
    /// @dev `commitmentHash == keccak256(abi.encode(jobId, resultHash))`, recomputed on-chain.
    event Released(bytes32 indexed jobId, bytes32 resultHash, bytes32 commitmentHash, address provider, uint256 amount);
    /// @notice Emitted when a consumer refunds a job after its deadline.
    event Refunded(bytes32 indexed jobId, address consumer, uint256 amount);

    /// @notice Consumer locks `msg.value` for `jobId`, naming the provider and attestor.
    /// @dev MUST revert if the job already exists, on zero value, on a zero address, or
    ///      on a non-future deadline.
    function open(bytes32 jobId, address provider, address attestor, uint256 deadline) external payable;

    /// @notice Release the escrow to the provider on proof the attestor signed the result.
    /// @param jobId      the job to settle
    /// @param resultHash keccak256 of the delivered result (the WYRIWE result hash)
    /// @param signature  EIP-191 personal_sign by the attestor over
    ///                   `commitmentHash = keccak256(abi.encode(jobId, resultHash))`
    /// @dev The commitment is recomputed from `jobId` on-chain, so a valid signature is
    ///      bound to this exact job and cannot be replayed against another open job that
    ///      shares the same result. MUST revert unless the job is Open and the recovered
    ///      signer equals the job's attestor.
    function release(bytes32 jobId, bytes32 resultHash, bytes calldata signature) external;

    /// @notice Refund the consumer if the deadline passed without a valid release.
    /// @dev MUST revert unless the job is Open and `block.timestamp >= deadline`.
    function refund(bytes32 jobId) external;

    /// @notice The escrowed job for `jobId`.
    function jobs(bytes32 jobId) external view returns (
        address consumer,
        address provider,
        address attestor,
        uint256 amount,
        uint256 deadline,
        Status  status
    );
}
