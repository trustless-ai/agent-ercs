# attester_diversity.v0 — diversity-weighted `attestationCount` for ERC-8275's reputation axis

**Gap closed:** raised by Dipankar Sarkar (Substack @sarkardipankar), design converged with
Tiago Merlini (ERC-8275 co-author) and babyblueviper1 (reputation-axis co-author) over a 28-round
public exchange (posted `ethereum/ERCs#1774`, issuecomment-5013819926 / -5017235227).

`attestationCount` in the current spec text (Appendix A.3.2) is **signature-gated**: it counts
only distinct verdict `event_id`s whose signature verifies against the validator's published key
— so the *attested* party cannot self-inflate it. That closes one Sybil vector but leaves a
second, structurally identical one open: **nothing stops N distinct, validly-signed attestations
from tracing back to M << N actual attester-*operators*.** A single party running M signing keys
produces M valid, distinct-`event_id` attestations that all count as if they were M independent
judgments — a Sybil ring of *verifiers*, not of the attested address.

## The fix

Weight `attestationCount` by attester-operator independence, using the same mechanism
`counterpartyDiversity` already uses for its own diversity axis: consume the operator-diversity
claims of a composing ERC-8294 validation network (§ Composition with ERC-8294) rather than
re-deriving operator identity locally.

Given `share_i` = operator *i*'s fraction of an agent's total attestation weight:

```
attestationCountEffective = 1 / Σ(share_i²)
```

The standard inverse-Simpson / inverse-HHI effective-number-of-independent-players formula.
Properties (all pinned by the vectors below):

- Collapses to **1** when every attestation traces to a single operator, regardless of raw count
  (`single-operator-sybil-ring`: 5 sig-valid attestations, 1 true operator → 1.0, not 5).
- Equals **K** when attestation weight is evenly spread across K independent operators
  (`three-independent-operators-even`: 3 operators × 4 each → 3.0, matching raw count exactly —
  diversity-weighting is a no-op in the honest case, not a penalty).
- Sits strictly between the two bounds for genuine partial diversity
  (`skewed-diversity`: one operator holds 8/12, two hold 2/12 each → 2.0).
- Where no composing ERC-8294 network exists (a single-issuer reference feed — e.g. this spec's
  own `api.babyblueviper.com/ledger`), `attestationCountEffective` trivially equals 1: an honest,
  conservative floor, not a special case requiring separate logic.

## Non-goals

This vector tests the **arithmetic** only: given a correctly-labelled `trueOperator` per
attestation, does the implementation compute `1/Σ(share_i²)` correctly and refuse to substitute
the raw signature-valid count. It does **not** test whether an implementation can *infer*
`trueOperator` from raw attestation data when labels are withheld (timing/overlap correlation,
key-reuse patterns, etc.) — that is a separate, harder adversarial-inference problem that
Dipankar Sarkar identified as the real remaining attack surface (a party could shape attestation
timing so one true operator resolves into several weakly-correlated apparent clusters, scoring a
healthy `N_eff=3` instead of the true `1`). That second vector is intentionally **not** included
here — Sarkar asked to post it himself, in his own words, once landed in the actual spec PR
thread; this suite leaves room for it as a natural `attester-diversity-v1` follow-on rather than
building it on his behalf.

## Recompute (any party, public data + a composing 8294 network's operator-diversity claims)

```
shares = { op: count(sigValid attestations where trueOperator == op) / count(all sigValid attestations)
           for op in distinct_operators(log) }
attestationCountEffective = 1 / sum(s**2 for s in shares.values())
```

## Files

- `attester-diversity-v0.vectors.json` — 5 pinned vectors (fixed seed 8275 for synthetic key
  material only — the scored quantity is deterministic and carries no randomness).
- `generate_vectors.py` — reproduces the vectors byte-for-byte from the pinned block structure.
- `gate.ts` — the checker (`bun gate.ts` self-checks against pinned `expected`; `--tamper` runs
  the naive raw-count method as the counterexample, mismatching on every non-trivial vector).
