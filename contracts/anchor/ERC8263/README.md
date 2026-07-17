# ERC-8263: Onchain Proof Layer for AI Agents

- **Spec**: [ERC-8263 (ethereum/ERCs PR #1748)](https://github.com/ethereum/ERCs/pull/1748)
- **Discussion**: [Ethereum Magicians #28577](https://ethereum-magicians.org/t/erc-8263-onchain-proof-layer-for-ai-agents/28577)
- **Status**: Draft
- **Author**: Vincent Wu (@TruthAnchor-AI)

## Interfaces

| File | Layer | Role |
|------|-------|------|
| `IOnChainProof.sol` | Anchor — write side | Anchors a non-zero 32-byte commitment (`proofHash`) plus an identity-scheme byte and 32-byte `agentId`, emitting exactly one canonical `AnchorProof` event per anchor. Topic0 `0x9fe832d83a52f83bd7d54181e4cc7ff8b4e227cc1d3a0144376894b5df6c23cc`. |

## Architecture

```
action payload ──H(profile)──▶ proofHash ──anchor()/anchorWithAux()──▶ AnchorProof(scheme, agentId, proofHash, operator, aux)
                                                                            │
off-chain verifier ◀── recompute proofHash from the observation, match log + block/tx (chain state only)
```

One canonical event across both entrypoints keeps a single topic0 for every indexer.
The contract performs no verification and no profile detection: `proofHash` is an
opaque non-zero `bytes32` commitment. Verification belongs entirely to off-chain
verifiers, which recompute `proofHash` from the observation under the declared
profile and match it against the `AnchorProof` log from chain state — no dependency
on the issuing service, indexer, or any hosted gateway.

### AgentId scheme registry

| `agentIdScheme` | Name | `agentId` derivation |
|:-:|---|---|
| `0x00` | ANONYMOUS | `bytes32(0)` (contract-enforced) |
| `0x01` | REGISTRY | 32-byte registry record id (ERC-8004 or compatible) |
| `0x02` | URI_HASH | `keccak256(canonical agent URI)` |
| `0x03+` | reserved | rejected at contract level |

### Canonical-form guards (write-time invariants)

`proofHash != 0`; scheme `0x00` requires `agentId == 0`; schemes `0x01`/`0x02`
require `agentId != 0`; schemes `0x03+` revert. Indexers can rely on these without
re-validating, but MUST NOT infer authorization, identity correctness, or payload
validity from the event alone — those belong to higher-layer verifier profiles.

## Boundary and composition

ERC-8263 is the **write-side anchor / commitment floor** (`anchor/`), deliberately
distinct from read-side verification (`verify/`):

- **ERC-8004 (`identity/`)** — identity binding under scheme `0x01`; the anchor
  carries `(agentIdScheme, agentId)` as opaque bytes, resolution is one-way and
  registry-agnostic.
- **ERC-8281 / OCP (`verify/`)** — read-side observation extraction and re-check
  digests. Every anchor is OCP-extractable by construction, but this ERC takes no
  dependency on OCP and anchors remain valid for verifiers that ignore it.
- **ERC-8274 (`verify/`)** — output/inference verification; sibling layer
  (8263 writes, 8274 reads).
- **ERC-8299 (`verify/`)** — input-provenance discipline is a profile concern over
  `proofHash` pre-images, not a contract concern.
- **ERC-8275 (`reputation/`)** — declares `requires: 8263`; settlement-derived
  reputation composes over `AnchorProof` history.

`aux` is explicitly non-normative: an opt-in extension surface for adjacent
protocols (OCP digest commitments, session ids, parent-proof references).
Adjacent-protocol extraction is profile-defined over `proofHash`, over `aux`, or
both — the ERC itself prescribes no mapping.

## Reference deployments (informative)

Etherscan-verified contracts implementing this interface unchanged:

- Ethereum Mainnet: `0xe95d6a15966984c209a62a2c188828555eb5ec3d`
- Sepolia Testnet: `0x89EE9b68c3b2f50cbE9D0fC4Dc134939a0475c1C`

Per the repository rule, everything here is recomputable from public data: the
event topology and guards can be confirmed by reading the verified sources and
chain logs directly.
