# ERC-8354: Confidential Agent Policy Verdicts

- **Spec**: [ERC-8354](https://github.com/ethereum/ERCs/pull/1919)
- **Discussion**: [Ethereum Magicians #29088](https://ethereum-magicians.org/t/erc-8354-confidential-agent-policy-verdicts/29088)
- **Reference implementation**: [zexoverz/confidential-agent-policy-verdicts](https://github.com/zexoverz/confidential-agent-policy-verdicts) (Noir circuit + UltraHonk verifier, real proof verifies on-chain)
- **Status**: Draft
- **Authors**: Muhammad Zidan Fatonie, Faisal Firdani, Maulana Asykari Muhammad

The confidential member of the `verify/` category. Where the others verify a computation transparently, ERC-8354 proves an agent action was permitted by a policy that is never revealed on-chain.

## Interfaces

| File | Role |
|------|------|
| `IConfidentialPolicyVerdict.sol` | The Guard: `verify` / `consume` / `isConsumed`, and the `Verdict` envelope (normative core, interfaceId `0xd6da8150`) |
| `PolicyAction.sol` | Canonical action-commitment preimage, domain-separated by `chainId` + `domainId`, hashed identically on-chain and in-circuit |
| `IPolicyDomainRegistry.sol` | Companion registry: domains, root rotation with grace, immediate revocation |
| `IIdentityRegistry.sol` | The single ERC-8004 call a Guard needs, an ERC-721 `ownerOf` read, declared minimally instead of importing ERC-8004 in full |
| `IVerifier.sol` | The prover-agnostic verifier boundary a domain's program is checked against: `verifyProof(programKey, publicInputs, proof)` |
| `IPolicyAttestation.sol` | The attestation a consumed verdict hands to ERC-8004's Validation Registry, with `MECHANISM_ZK_SECRET_POLICY` as the source-class tag |

This is the complete ERC-8354 asset set from the merged spec. Every file here
is byte-for-byte identical to `assets/erc-8354/src` in
[ethereum/ERCs#1919](https://github.com/ethereum/ERCs/pull/1919).

## Where it sits

```
Guarded contract
    └── IConfidentialPolicyVerdict (this ERC)
            ├── ERC-8004 identity   (agentId)
            ├── ERC-7812 evidence   (policyRoot, the committed secret policy)
            ├── ERC-8312 metering   (composes: bounded actions)
            └── IVerifier backend   (prover-agnostic; MAY be an ERC-8274 IProofVerifier)
```

An off-chain policy engine evaluates an agent action against a secret ruleset committed as an ERC-7812 root, and emits a zero-knowledge proof binding the verdict to an ERC-8004 identity, the policy root, a commitment to the action, the executor, an expiry, and a single-use nullifier. The Guard verifies that proof locally and gates execution on it, without the policy ever appearing on-chain.

## Composition with this stack

- **ERC-8274** — the CAPV verifier boundary is prover-agnostic (`IVerifier.verifyProof(programKey, publicInputs, proof)`). A domain MAY use an ERC-8274 `IProofVerifier` as that backend, so the same interface that verifies the inference also verifies the policy verdict.
- **ERC-8004** — `Verdict.agentId` is an ERC-8004 Identity Registry token id. A domain MAY declare that registry as `Domain.identityRegistry`. Where declared, `consume` MUST reject a verdict whose `agentId` is not a live token there, with `AgentUnknown`. Where undeclared (`address(0)`), no such check runs and `agentId` stays an opaque, cryptographically bound public input.
- **ERC-8312** — an action can be both within a bounded mandate (8312) and permitted by a confidential policy (8354); the two compose cleanly.

## Related ERCs (the two corners)

- [ERC-8274 / AI Inference Proof Verification](https://github.com/ethereum/ERCs/pull/1771) — verifies the computation ran (recomputable or proof-attested). Orthogonal: 8354 is confidential-correct, not public-recomputable.
- [ERC-8281 / OCP](https://ethereum-magicians.org/t/draft-erc-observation-commitment-protocol-ocp-chain-agnostic-cryptographic-commitment-primitive/28399) — observation commitment (recompute-and-compare). 8354 occupies the corner that cannot be recomputed, the policy is never revealed.
- [ERC-8299 / WYRIWE](https://ethereum-magicians.org/t/wyriwe-what-you-read-is-what-you-execute-input-provenance-for-verifiable-ai-inference/28655) — transparent input provenance. A confidential provenance variant is future work.
