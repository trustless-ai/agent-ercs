# verify_outcome.v0 — chain-recomputable proofs for ERC-8275 `verifyOutcome(orderId, proof)`

**Gap closed:** `IAgentReputation.verifyOutcome` had no pinned vectors and its proof format was
"implementation-defined", while `attester-diversity-v0` next to it had pinned vectors. Raised by
Petchevere, who hit the same shape in production: x402#3824, where a settlement field was declared
but not enforced at verification and the facilitator's report said more than the chain backed
(fixed by recomputing from the ledger, settlement-evidence-ref at 225a617). Boundary framing
(Settlement -> Reputation is pinned first) by Pavlo. The tri-state outcome and the coverage
carry-over by Echo. Semantics confirmed as normative by the ERC-8275 author,
Panini (@OnThe_Stars), in the 8275 working group, 2026-10-17.

## Why it matters

`verifyOutcome` is where a settlement becomes a reputation input, and that score decides who wins
the next order. If a verifier accepts the facilitator's word, or a real settlement that belongs to
another order, a provider's win rate can be inflated without any money moving to them for the
order being scored.

## Semantics

A proof in this profile carries `chainId`, `txHash`, `releaseLogIndex` and
`governing_convention_hash`. The verifier recomputes everything from the chain, never from the
presenter or the facilitator:

1. The receipt for `txHash` on `chainId` exists and has `status == 1`.
2. The log at `releaseLogIndex` in **that receipt** is the escrow's release event, emitted by the
   order's escrow, with `topics[1] == orderId`, and its payee and amount equal the order's
   provider and amount.
3. **The same receipt** contains an asset `Transfer` from the escrow to the provider for the order
   amount. Logs come from the proven receipt only, never from a scan of the block.
4. `governing_convention_hash` equals the convention the verifier scores under
   (`win_rate.bps.v0` = `0x0501b75db8e9ef4ef67c74efcfbe2a200b0a7e5aea5ca62f778c91c119e68daf`).

Three outcomes, fail-closed:

| Outcome | When |
|---|---|
| `verified` | 1-4 hold |
| `rejected` | no tx to recompute from, or any of 1-3 is contradicted by the chain |
| `unverifiable` | the verifier cannot reach `chainId` or retrieve the receipt, or the proof was scored under a different convention hash |

`unverifiable` is never collapsed into `verified` (that accepts on the facilitator's word) or
`rejected` (that rejects a proof that may be sound). It is the same resolution
`conventions.py verify()` gives an unknown convention hash. A proof scored under a different
convention hash is unverifiable **for that score**; it is not re-scored under the verifier's own
convention. For `bool verifyOutcome(...)`, `valid == true` iff the outcome is `verified`; an
off-chain verifier that reports results MUST report `unverifiable` as its own state.

## Coverage clause

A score published without `settled_count` beside it is non-conformant: without the count, "not
enough history" and "poor outcomes" are indistinguishable, and `verifyOutcome` is where that
count starts.

## Vectors

10 pinned vectors in `verify-outcome-v0.vectors.json`. The confirmed semantics list 6
settlement-evidence cases plus the unverifiable case; "amount or payee mismatch" is split into
two vectors, the unverifiable case into its two triggers, and the convention-hash rule gets its
own vector, so each rule has exactly one vector that tests it.

| Vector | Expected |
|---|---|
| `positive-release-matches-order` | verified |
| `facilitator-report-only-no-tx` (the x402#3824 shape) | rejected |
| `valid-tx-for-different-order` | rejected |
| `amount-mismatch` | rejected |
| `payee-mismatch` | rejected |
| `reverted-tx` | rejected |
| `transfer-in-other-tx-same-block` | rejected |
| `chain-unreachable` | unverifiable |
| `receipt-not-retrievable` | unverifiable |
| `governing-convention-hash-mismatch` | unverifiable |

Each vector has a `chain` fixture standing in for `eth_getTransactionReceipt` per reachable
`chainId`; a live adapter replaces it with RPC calls. The release event is
`Released(bytes32 indexed, bytes32, bytes32, address, uint256)` from
`contracts/settlement/ConsultEscrow/IConsultEscrow.sol`, emitted here by an ERC-20 escrow.

## Mutation controls

`python3 check.py --mutants` runs 9 lax checkers, each dropping one rule. Every one must diverge
from the pinned outcomes on at least one vector, or the suite has no bite:

trust-facilitator-report, no-order-binding, no-amount-check, no-payee-check, ignore-status,
scan-block-for-transfer, unverifiable-as-rejected, unverifiable-as-verified, ignore-convention-hash.

## Non-goals

- Native-value escrows. `ConsultEscrow` itself pays ETH with a value call, which emits no
  `Transfer` log; rule 3 has no log to read there. Binding amount and payee for native payouts needs
  the call trace or a balance diff, and is a separate `verify-outcome-v1` profile rather than a
  weaker rule here.
- Finality. The fixture treats a retrievable receipt as final. A live verifier should require its
  own confirmation depth and answer `unverifiable` until it is reached.
- Other proof formats (e.g. a Merkle proof against a published settlement root) remain allowed by
  the interface; this profile pins the one that needs no trust in any root publisher.

## Files

- `verify-outcome-v0.vectors.json` — the 10 vectors.
- `generate_vectors.py` — reproduces the vectors byte for byte (stdlib only).
- `check.py` — stdlib checker: `python3 check.py` self-checks, `--mutants` runs the controls,
  `--grade` is the stdio adapter (fixture on stdin, `{name: {"outcome": ...}}` on stdout).
