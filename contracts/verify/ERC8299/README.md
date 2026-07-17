# ERC-8299: WYRIWE — Input Provenance for AI Inference

- **Spec**: [ERC-8299 (ethereum/ERCs PR #1810)](https://github.com/ethereum/ERCs/pull/1810)
- **Status**: Draft
- **Authors**: TMerlini, TruthAnchor-AI, Damonzwicker, JimmyShi22, babyblueviper1

## Interfaces

| File | Layer | Role |
|------|-------|------|
| `IWyriweAttestation.sol` | L3 — input provenance | Binds what a user submitted (`rawInputHash`) to what the model actually received (`inputHash`) via a public, replayable sanitization pipeline. `claimType = Attestation`. |
| `IJudgmentExecutionAttestation.sol` | L4 — judgment validator chain-of-custody | One layer up: binds a proposed action to the verdict that judged it and, at settlement, to the action actually executed. `claimType = Judgment`. Primary-authored by babyblueviper1; production reference `api.babyblueviper.com/ledger`. |

Both share the `ClaimType` enum (`../../interfaces/IClaimType.sol`) and the `ERC8004AttestationGateway` / v1 EIP-712 domain — the L4 gateway reuses the L3 domain by design rather than forking verifier code paths.

## Architecture

```
WyriweAttestation (L3)              JudgmentExecutionAttestation (L4)
  rawInputHash                        rawProposalHash
  sanitizationPipelineHash            verdictHash
  inputHash                           executedActionHash
  IDENTITY_SENTINEL (no-op case)      unconditional-approve (executed-as-reviewed case)
```

Same triple-hash shape, one layer up: WYRIWE proves what a model actually processed; the L4 composition proves a judgment validator's verdict was bound to the specific proposal it reviewed and to the action actually taken afterward.

## Reference implementation

`https://api.babyblueviper.com/ledger` — live production judgment validator (L4), running against real capital. `/ledger/{n}/commitment` and `/ledger/{n}/outcome` implement the `RecordPointer` commitment/outcome separability invariant (spec Appendix B) — a consumer can check commitment without outcome (pre-settlement) and outcome without re-deriving commitment (post-settlement).

## Related ERCs

- [ERC-8274](../ERC8274) — AI Inference Proof Verification Interfaces (the `IProofVerifier` / `IAgentVerifier` layers WYRIWE attestations flow through)
- [ERC-8004](../../identity/ERC8004) — agent identity registry (`agentId` / `registry` fields)
