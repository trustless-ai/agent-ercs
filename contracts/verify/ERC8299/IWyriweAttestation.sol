// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IClaimType} from "../../interfaces/IClaimType.sol";

/// @title IWyriweAttestation — Input Provenance for AI Inference (L3)
/// @notice Triple-hash construction binding what a user submitted (`rawInputHash`) to
///         what the model actually received (`inputHash`) via a publicly verifiable
///         sanitization pipeline (`sanitizationPipelineHash`).
/// @dev    Part of ERC-8299 (WYRIWE). EIP-712 typed struct, domain
///         `{name: "ERC8004AttestationGateway", version: "1", chainId: block.chainid}`.
///         Field ordering is normative — reordering changes the EIP-712 typeHash.
///         claimType = Attestation (see IClaimType). proofSystem() = "attestation/wyriwe".
interface IWyriweAttestation is IClaimType {
    /// @notice EIP-712 typed structured data for a single WYRIWE-compliant execution.
    /// @dev Type string (normative field order):
    ///      WyriweAttestation(bytes32 agentId,address registry,bytes32 modelHash,
    ///      bytes32 rawInputHash,bytes32 sanitizationPipelineHash,bytes32 inputHash,
    ///      bytes32 outputHash,uint256 timestamp)
    struct WyriweAttestation {
        bytes32 agentId;                  // ERC-8004 agent identity anchor; MAY be zero if unregistered, MUST NOT be omitted
        address registry;                 // ERC-8004 registry address
        bytes32 modelHash;                // hash of model weights or manifest
        bytes32 rawInputHash;             // keccak256(raw_user_input)
        bytes32 sanitizationPipelineHash; // keccak256(sanitization_spec_cid_bytes || rawInputHash);
                                           // IDENTITY_SENTINEL_CID case: keccak256(IDENTITY_SENTINEL_CID || rawInputHash)
        bytes32 inputHash;                // keccak256(sanitized_input); equals rawInputHash under the identity sentinel
        bytes32 outputHash;               // keccak256(model_output)
        uint256 timestamp;                // unix timestamp of execution
    }

    /// @notice Verify a WYRIWE attestation's EIP-712 signature against the known attestor.
    /// @dev Full conformance also requires steps 2-4 of the spec's Verification Procedure
    ///      (recomputing rawInputHash and the sanitization pipeline off-chain against the
    ///      pinned sanitization_spec_cid) whenever the referenced inputs are available —
    ///      those steps are off-chain/gateway responsibilities, not expressible on-chain.
    /// @param attestation The WyriweAttestation struct.
    /// @param signature   65-byte (r, s, v) ECDSA signature over the EIP-712 digest.
    /// @return valid True if the signature recovers to the known attestor address.
    function verify(WyriweAttestation calldata attestation, bytes calldata signature)
        external
        view
        returns (bool valid);

    /// @notice Human-readable proof-system identifier for the IProofVerifier path.
    /// @return Always "attestation/wyriwe" for conforming implementations.
    function proofSystem() external view returns (string memory);
}
