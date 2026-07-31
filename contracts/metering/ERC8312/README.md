# ERC-8312: Bounded Agent Actions

- **Spec**: [ERC-8312 (ethereum/ERCs PR #1833)](https://github.com/ethereum/ERCs/pull/1833)
- **Status**: Draft
- **Authors**: Matthias Hauser (@0x2kNJ), Simon Brown (@orbmis)
- **Discussion**: [ethereum-magicians.org/t/28851](https://ethereum-magicians.org/t/erc-8312-bounded-agent-actions/28851)

## Interfaces

| File | Role | ERC-165 id |
|------|------|------------|
| `IBoundedAgentAction.sol` | Base envelope: principal, immutable `capabilityRoot`, mutable `cursorRoot`, expiry, lifecycle. The cursor is the one written object every value-drawing surface advances. | `0x3985961d` |
| `IBudgetSubstrate.sol` | Budget profile read surface: `bound` / `spent` / `remaining`, with `spent <= cap` and monotone spent as the interoperable guarantee. | `0x021ca455` |
| `IContestableEnvelope.sol` | Optional contestation extension: `contest` / `resolve` over the Contested state. | `0xe664d441` |
| `IAggregateBudget.sol` | Optional aggregate-budget profile: one conserved root cap across a whole delegation tree. `spentRoot` is the meter; `Σ draws ≤ cap` per period regardless of fan-out, depth, or re-delegation. | `0xc7cabe86` |

InterfaceIds are frozen; regenerate if any function signature changes.

## What it defines

The cap is the one invariant in a composed agent flow that a read cannot hold:
it is a sum across steps, and a check-time read sees an incomplete surface. The
cursor holds it by ordering (a serialized write every surface advances) and the
public `EnvelopeAdvanced` record keeps it auditable: any party recomputes
whether cumulative consumption ever exceeded the cap, with no trusted meter.

The cursor meters; it does not enforce. Non-bypassability is a substrate
property: the registry documents the mechanism that routes value through
`advanceCursor` (an escrow or vault holding the assets, a module on the
account's only execution path, or a counter fused into the transfer itself).

```
agreement (ERC-8001)       records the accepted authority
cursor (ERC-8312)          meters consumption against it, pre-action
workflow (ERC-8301)        orders the steps; each drawing step advances the cursor
verify (ERC-8263/8274)     gates the witness before a draw counts
settlement (ERC-8275)      moves value after the fact
```

## Aggregate budget profile (`IAggregateBudget`)

The base profile meters one envelope. The aggregate profile meters a whole
delegation tree against a single conserved root cap: an agent spawns
sub-agents, which re-delegate further, each under its own key, and the sum of
admitted draws across every node in a period stays within one root budget. A
tree is not an envelope, so `IAggregateBudget` does not extend
`IBoundedAgentAction`; an implementation may expose both ids.

Two conformance facts carry the profile (spec Section 5):

- **Edge-keyed accounting is non-conformant.** A fresh counter per delegation
  edge — the shape of per-grant allowances, caveat chains, session keys,
  ERC-7710 redelegation — admits an unbounded aggregate: a root opening *k*
  sibling paths capped at *B* realizes *k·B* while every per-edge check passes.
- **The meter is root-keyed and admin-free.** `spentRoot` is the sum over the
  whole tree, and no owner, upgrade, or administrative authority may reset,
  decrement, or replace it. A meter behind such an authority is conserved only
  until the authority is exercised.

Supporting rules: `revoke` never decrements the meter (realized spend stays
realized); a node with a nonzero `nodeCap` cannot delegate (a capped node would
otherwise mint an uncapped child and escape its cap); `nodeCap` attenuates one
node's own draws and is **not** a subtree budget. Unlike the base profile there
is no commitment scheme to recompute — `spentRoot` is the plain conserved
meter, readable directly. Scope: safety on a single chain; non-bypassability
remains a substrate obligation.

## Reference implementations

- [`Atlas-Protocol-AI/bounded-agent-actions`](https://github.com/Atlas-Protocol-AI/bounded-agent-actions) — CC0 `EnvelopeRegistry` implementing the base interface and budget profile, with a conformance suite; `AggregateBudgetCursor` implementing the aggregate profile, with a conformance suite, a stateful conservation invariant over randomized trees, and a per-edge counter mock realizing `2B` through two sibling paths as the non-conformance witness.
- [`Atlas-Protocol-AI/zero-human-loop`](https://github.com/Atlas-Protocol-AI/zero-human-loop) — end-to-end composition (standing, mandate, provenance, escrow) with the aggregate-bound race proven on-chain on Base Sepolia.
- [`Echo-Merlini/cap-conservation-audit`](https://github.com/Echo-Merlini/cap-conservation-audit) — independent recompute: proves `reserved + confirmed <= cap` from storage via `eth_getProof` against the state root, no trusted meter read.


## Golden vectors (budget profile)

For SDK recompute functions, `cursorRoot = keccak256(abi.encode(uint256 spent))`:

| spent | cursorRoot |
|-------|------------|
| `0` (initial) | `0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563` |
| `100` | `0x26700e13983fefbd9cf16da2ed70fa5c6798ac55062a4803121a869731e308d2` |

Consistency check while Active: `keccak256(abi.encode(cap - remaining(id))) == getCursor(id)`.
A minimal flat instance is deployed on Base Sepolia at `0x8e6c805F6924d030ab3063C197b26C464dA124A1`.

The ERC text is canonical; this directory mirrors the interface in PR #1833.
