// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

/// @title Reproducible Contenthash Commitment
/// @notice An ENS contenthash that only moves when N independent parties have each
///         rebuilt a stated source commit and derived the same bytes and the same CID.
///
/// @dev For content published through ENS, the contenthash is typically the ONLY value
///      in the system no third party can re-derive. Everything under it — a signature,
///      a content hash, an attestation — is verifiable from primary sources. The
///      contenthash is a transaction someone sent, pointing at bytes they chose.
///
///      That asymmetry is sharpest where the page is not decoration but the interface
///      through which readers evaluate the data underneath. Whoever controls it controls
///      what the world believes the data says, and no amount of verifiable data below
///      repairs that.
///
///      Authorising several addresses to write the record solves availability by ADDING
///      unilateral paths — the opposite of the property worth protecting. This separates
///      who may execute from what may be published, and constrains the second.
interface IReproducibleContenthash {
    /// @param recordDigest binds cid, commit, treeHash and cidParamsHash together
    /// @param treeHash     what THIS signer derived — depends on the bytes alone
    /// @param cid          what THIS signer derived — depends on bytes AND cidParams
    /// @param rebuiltAt    when this signer ran the rebuild
    /// @param signature    EIP-712 over the whole confirmation, not a chosen subset
    struct Confirmation {
        bytes32 recordDigest;
        bytes32 treeHash;
        bytes   cid;
        uint64  rebuiltAt;
        bytes   signature;
    }

    event ContenthashCommitted(
        bytes32 indexed node,
        bytes   cid,
        bytes32 commitHash,
        bytes32 treeHash,
        uint64  sequence
    );

    event SignerSetChanged(address indexed signer, bool authorised);

    /// @notice Publish `cid` for `node` if enough distinct authorised signers confirm it.
    /// @dev MUST revert unless at least `threshold()` confirmations recover to DISTINCT
    ///      authorised signers over the same record digest.
    ///
    ///      MUST count only confirmations that verify AND assert the record's own
    ///      `treeHash` and `cid`. Presence in the array MUST NOT be sufficient: a party
    ///      merely named is not a party who confirmed, and conflating the two is how a
    ///      two-party rule degrades into a one-writer rule.
    ///
    ///      MUST reject a `recordDigest` already committed, and MUST require a strictly
    ///      increasing `sequence`. A threshold alone does not prevent republishing an
    ///      older, once-valid CID — its confirmations were genuine.
    function commit(
        bytes32 node,
        bytes calldata cid,
        bytes32 commitHash,
        bytes32 treeHash,
        bytes32 cidParamsHash,
        Confirmation[] calldata confirmations
    ) external;

    /// @notice Minimum distinct authorised signers required. MUST be >= 2.
    function threshold() external view returns (uint8);

    function isSigner(address who) external view returns (bool);

    /// @notice Strictly increasing per node. Rollback protection, not bookkeeping.
    function sequence(bytes32 node) external view returns (uint64);
}
