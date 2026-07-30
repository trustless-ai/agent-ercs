# ERC-8275: Agent Service Discovery and Escrow Payments — Reputation Layer

- **Spec**: [ERC-8275 (ethereum/ERCs PR #1774)](https://github.com/ethereum/ERCs/pull/1774)
- **Status**: Draft
- **Authors**: Panini (@Brooks1003), Tiago Merlini (@TMerlini), Damon Zwicker (@damonzwicker), Jimmy Shi (@JimmyShi22), Vincent Wu (@TruthAnchor-AI), babyblueviper1 (@babyblueviper1), Pocket Network VNI Group (@traciecmyers)

## Scope of this folder

ERC-8275 defines two economic axes: **Part I — service-layer interfaces** (discovery, escrow,
reputation) and **Part II — mesh-settlement interfaces** (contribution accounting, commit-reveal
settlement, node compensation). This folder covers only the **Reputation Layer** from Part I —
`IAgentRegistry`, `IAgentEscrow`, and the Part II mesh-settlement interfaces (node registry,
commit-reveal settler, EscrowV1) are out of scope here and open for a separate contribution.

## Interfaces

| File | Role |
|------|------|
| `IAgentReputation.sol` | Event-derived agent reputation — derived entirely from `IAgentEscrow` settlement events and, optionally, verified ERC-8299 (WYRIWE) attestation history. Derived-not-stored: every value recomputable from public data, no scorer to trust. |

Shares the `ClaimType` enum (`../../interfaces/IClaimType.sol`) with ERC-8299 — `ValidatorType` in
this interface is structurally identical to `ClaimType` by spec design (dual discriminator: an
EIP-712 type string carries on-chain schema discrimination, this enum carries off-chain indexer
readability).

## Reputation function shape

`f(attestationCount, counterpartyDiversity, winRate, volumeCap)` — losses remain in the record
(a feed that hid its losses would be marketing, not reputation); weighting favours distinct
at-stake counterparties over call volume; `volumeCap` ceilings the volume weight by
`(winRate × settled-count)` so raw call volume alone cannot dominate the outcome axis.

## Reference implementation

`https://api.babyblueviper.com/ledger` — the spec's named reputation reference feed (Appendix A.3,
primary-authored by babyblueviper1). Every `attestationCount`/`winRate`/`committed_at`/
`counterpartyDiversity` input is recompute-grade: count distinct signed `event_id`s that verify
against the published `verifier_pubkey`, read win/loss off the public settled account, and confirm
`committed_at` predates the outcome via the ERC-8263 anchor — no step trusts the issuer's own
say-so. Full per-field mapping + recompute path: spec Appendix A.3.

## Attester-diversity weighting (Sybil resistance, closes a real spec gap)

Signature-gating `attestationCount` stops the *attested* party from self-inflating it, but a
second, structurally identical gap stayed open until now: nothing stopped N distinct,
validly-signed attestations from tracing back to M << N actual attester-*operators* (a Sybil
ring of verifiers, not of the attested address) — raised by Dipankar Sarkar
(@sarkardipankar), design converged with Merlini and babyblueviper1 over a 28-round public
exchange (`ethereum/ERCs#1774`, issuecomment-5013819926 / -5017235227).

Fix: weight `attestationCount` by attester-operator independence, sourced the same way
`counterpartyDiversity` already sources its own diversity (a composing ERC-8294 network's
operator-diversity claims) — `attestationCountEffective = 1 / Σ(share_i²)`, the standard
inverse-Simpson / inverse-HHI effective-number-of-independent-players formula. Collapses to 1
when every attestation traces to one operator regardless of raw count; equals K when evenly
spread across K independent operators.

Real, runnable conformance suite: [`conformance/attester-diversity-v0/`](../../../conformance/attester-diversity-v0)
— 5 pinned vectors (including the Sybil-ring counterexample), `bun gate.ts` self-checks against
them, `--tamper` runs the naive raw-count method to show exactly where it diverges. The harder
adversarial-inference half of this problem (can an implementation *infer* operator identity from
raw attestation timing/overlap when labels are withheld) is intentionally left open — Sarkar's
own follow-on point, left for him to land in his own words rather than built on his behalf.

## Related ERCs

- [ERC-8299](../../verify/ERC8299) — WYRIWE attestation fields this reputation layer optionally
  consumes (`inputHash` for counterparty derivation, `timestamp` for the committed_at gate).
- [ERC-8274](../../verify/ERC8274) — verification interfaces the attestation history flows through.
- [ERC-8004](../../identity/ERC8004) — agent identity registry (`agentId` anchor).
- ERC-8263 (Precedence / OTS Anchor) — on-chain anchor establishing `committed_at` precedence; no interface folder in this repo yet (also on Jimmy's needed list).
