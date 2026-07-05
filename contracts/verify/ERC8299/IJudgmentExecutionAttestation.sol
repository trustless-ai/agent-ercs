// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IClaimType} from "../../interfaces/IClaimType.sol";

/// @title IJudgmentExecutionAttestation — Judgment Validator Chain-of-Custody (L4)
/// @notice One layer up from IWyriweAttestation (L3, input provenance): binds "action
///         reviewed" to "action executed after verdict" with the same triple-hash shape.
///         rawProposalHash = what the agent proposed; verdictHash = the judgment,
///         binding to rawProposalHash so a verdict cannot be replayed against a
///         different proposal than the one it judged; executedActionHash = what was
///         actually executed, revealed at settlement.
/// @dev    Part of ERC-8299 (WYRIWE) Composition section. Same EIP-712 domain as
///         IWyriweAttestation by design (a dedicated judgment gateway SHOULD reuse it
///         rather than forking verifier code paths). claimType = Judgment (see
///         IClaimType). proofSystem() = "attestation/judgment".
///
///         verify() == true authenticates that the verdict is genuinely the validator's
///         and correctly bound to the reviewed task inputs. It does NOT mean the
///         judgment was sound, that the action should have proceeded, or that the
///         verdict has been independently endorsed — verdict weight lives in the
///         accountability record reachable via recordPointer, not in this bool.
interface IJudgmentExecutionAttestation is IClaimType {
    /// @notice On-registry vs off-registry validator identity locator, plus separately
    ///         resolvable pre-settlement (commitment) and post-settlement (outcome)
    ///         evidence. NOT part of the EIP-712 signed type — the attestation is
    ///         signed once and frozen at verdict time; the record this points to is
    ///         alive and grows as outcomeEvidence accumulates. Resolved off the
    ///         `recordPointer` URI's `/commitment` and `/outcome` sub-paths.
    struct RecordPointer {
        bytes32 validatorId;    // ERC-8004 identity of the judgment validator; zero =
                                 // off-registry, identity MUST resolve from the verdict
                                 // artifact itself (e.g. schnorr pubkey of a signed Nostr event)
        bytes32 registryType;   // keccak256 of a registry-type string, e.g.
                                 // "evm/registry", "nostr/profile", "offchain/ledger"
        bytes registryRef;      // registry-specific locator (contract address + agentId,
                                 // Nostr pubkey, base URL, ...)
        bytes commitmentProof;  // pre-settlement evidence: signed verdict, relay anchor,
                                 // commit hash. SHOULD open with a self-describing
                                 // mechanism-identifier byte prefix.
        bytes outcomeEvidence;  // post-settlement evidence: settlement account, outcome
                                 // digests. MAY be empty before settlement closes.
    }

    /// @notice EIP-712 typed structured data binding a judgment verdict to its reviewed
    ///         proposal and, at settlement, to the action actually executed.
    /// @dev Type string (normative field order):
    ///      JudgmentExecutionAttestation(bytes32 agentId,address registry,
    ///      bytes32 validatorId,bytes32 rawProposalHash,bytes32 verdictHash,
    ///      bytes32 executedActionHash,uint256 verdictTimestamp,
    ///      uint256 executedTimestamp,string recordPointer)
    ///      Commit-reveal invariant: verdictTimestamp < executedTimestamp MUST hold.
    struct JudgmentExecutionAttestation {
        bytes32 agentId;             // ERC-8004 identity of the EXECUTING agent
        address registry;            // ERC-8004 registry address
        bytes32 validatorId;         // ERC-8004 identity of the judgment validator;
                                      // MUST NOT be omitted, zero signals off-registry
        bytes32 rawProposalHash;     // keccak256(canonical proposed-action artifact, pre-review)
        bytes32 verdictHash;         // keccak256(verdict_artifact_ref || rawProposalHash);
                                      // verdict_artifact_ref: IPFS CID or Nostr event ID
        bytes32 executedActionHash;  // keccak256(canonical executed-action record), revealed at settlement
        uint256 verdictTimestamp;    // verdict issuance — the commit, strictly pre-execution
        uint256 executedTimestamp;   // execution — the reveal
        string recordPointer;        // URI resolving to a RecordPointer-shaped record;
                                      // {recordPointer}/commitment and {recordPointer}/outcome
                                      // MUST remain separately resolvable; empty string if
                                      // not yet anchored
    }

    /// @notice Verify a judgment execution attestation's EIP-712 signature against the
    ///         known executing-agent attestor.
    /// @dev Only one signature is required here: the executing agent's attestor signs at
    ///      reveal time. The validator's own signature lives inside the verdict artifact
    ///      that verdictHash pins, so validator authenticity is carried without a second
    ///      signature field on this struct.
    /// @param attestation The JudgmentExecutionAttestation struct.
    /// @param signature   65-byte (r, s, v) ECDSA signature over the EIP-712 digest.
    /// @return valid True if the signature recovers to the known attestor address.
    function verify(JudgmentExecutionAttestation calldata attestation, bytes calldata signature)
        external
        view
        returns (bool valid);

    /// @notice Human-readable proof-system identifier for the IProofVerifier path.
    /// @return Always "attestation/judgment" for conforming implementations.
    function proofSystem() external view returns (string memory);
}
