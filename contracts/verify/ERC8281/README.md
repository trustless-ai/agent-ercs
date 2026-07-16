# ERC-8281: Observation Commitment Protocol (OCP)

- **Spec**: [ERC-8281 (ethereum/ERCs PR #1788)](https://github.com/ethereum/ERCs/pull/1788)
- **Status**: Draft
- **Author**: Damonzwicker
- **Interface contributed by**: TMerlini

## Interfaces

| File | Layer | Role |
|------|-------|------|
| `IObservationCommitment.sol` | Anchor — commitment | Anchors an opaque `digest` on-chain via `record(bytes32)`, emitting `Recorded(digest, committer)`. Tamper-evident, timestamped proof-of-existence; the observation itself stays off-chain. ERC-165 id `0xb5c645bd`. |

## Architecture

```
observation ──keccak256──▶ digest ──record()──▶ Recorded(digest, committer)
                                                    │
off-chain verifier ◀── recompute digest, match log + block/tx
```

Verification is recompute-based and off-chain — there is no on-chain getter. A verifier
re-derives the digest from the primary artifact and confirms the matching `Recorded` log
exists at the claimed block: the event log is the ledger. This keeps the anchor minimal
(one write, one event) and the observation private, while the commitment stays publicly
checkable by anyone holding the artifact.

## Reference implementation

`ObservationCommitment` — https://github.com/damonzwicker/observation-commitment-protocol

- **Canonical deploy (mainnet): `0x7186599d6Eb50905ecd34346e705E4C93871143b`** — verify commitments against this.
- Testnet reference only: `0x0963Fd33DF80c94360F2DC22e5c09517AeE7ED5c` (Base Sepolia). Do **not** verify a
  mainnet commitment against Sepolia logs — a commitment is only valid on the chain it was recorded on.
- Off-chain verifier: `ocp-verify@2.0.0` (npm) — 21-vector conformance suite
- ERC-165 interface id `0xb5c645bd` (implemented by the contract, not the interface)
- Extensions (separate contracts, **not** part of this base interface): Revocation,
  Temporal Bounds — candidates for `IObservationCommitmentRevocable` /
  `IObservationCommitmentTemporal` if/when specced.

## Related ERCs

- [ERC-8299](../ERC8299) — WYRIWE anchors its L3 input-provenance commitment (`inputHash`)
  through this `record` surface.
- [ERC-8274](../ERC8274) — proof-verification interfaces; TruthAnchorV1 sits alongside OCP
  as the anchor-event layer, composing with (not absorbing) this commitment primitive.
