# ConsultEscrow — Pay-on-Delivery Settlement for Agent Consultations

- **Spec anchor**: the **AccountabilityRecord / `OutcomeAttestation`** field set — `verifierKey`, `settlementVenue`, `settlementRef`, `verdictHash`, `result`, `publishesLosses`, `recordPointer` (see *AccountabilityRecord / OutcomeAttestation* below). ConsultEscrow is the canonical **on-chain custody + release leg underneath `AccountabilityRecord.recordPointer`**.
- **Status**: Draft — **base implementation deployed & Etherscan-verified on Ethereum mainnet**
- **Authors**: TMerlini (contract), babyblueviper1 (settlement / AccountabilityRecord shape)
- **Category**: `settlement` (new — the on-chain pay/settle link; per the repo README's "propose a new category if nothing fits"). No standalone ERC number — additive, and a standalone ERC may follow if this earns outside adoption.

## What it is

`ConsultEscrow` is the **trustless pay-on-delivery** primitive for the agent-standards stack, and the on-chain leg that was a spec-shaped hole under `AccountabilityRecord` / `recordPointer` since the Vouch crosswalk shipped. A consumer locks ETH for a consultation naming a `provider` and an `attestor`; the escrow releases to the provider **only** when the attestor signs the result's commitment, or refunds the consumer after a deadline if no valid result is delivered. Custody is fully on-chain — the consumer never trusts a platform-held balance, and **no valid signed result means no payment**.

This is the first *base implementation* in `agent-ercs` (not an interface-only entry): it is deployed, verified, and live on mainnet.

## Interfaces

| File | Role |
|------|------|
| `IConsultEscrow.sol` | The settlement interface — `open` / `release` / `refund` / `jobs`, the `Job` struct, `Status` enum, and the `Opened` / `Released` / `Refunded` events. |
| `ConsultEscrow.sol` | Base implementation. Checks-effects-interactions ordered; `release` security rests entirely on the attestor signature over the on-chain-recomputed, job-bound commitment. |

## The settlement commitment (recomputable)

```
resultHash     = keccak256(utf8(resultText))              // the delivered result
commitmentHash = keccak256(abi.encode(jobId, resultHash)) // recomputed ON-CHAIN in release()
release  ⟺  ecrecover(EIP-191(commitmentHash), sig) == job.attestor
```

`release(bytes32 jobId, bytes32 resultHash, bytes sig)` recomputes `commitmentHash` **from `jobId` on-chain**, so a valid attestor signature is bound to that exact job — it cannot be replayed against another open job that shares the same result hash. This closes a binding gap found in review (see `test_signature_isBoundToJobId`).

Every `Released` event is re-derivable from public data. The recompute is pinned as a first-class recipe + golden vector in [trustless-ai/recompute-kit](https://github.com/trustless-ai/recompute-kit):

```bash
bin/recompute-step 8203/settlement-proof <jobId> "<resultText>" <expected_commitmentHash>
# vector: settlement-proof-consult  (suite: CONFORMANT)
```

## AccountabilityRecord / OutcomeAttestation (spec anchor)

This is the spec ConsultEscrow implements. The delivering gateway emits an `OutcomeAttestation` (Vouch / S220 `AccountabilityRecord` field shape) off its `/proof` endpoint, straight off the same artifact the chain settled — and `settlementVenue` / `settlementRef` point back at this contract and its release tx:

```json
"outcomeAttestation": {
  "verifierKey": "0x85Fa13511D170FBe173761b63D7f8DD4A6f6Bf1A",
  "settlementVenue": "0x7057fbA75Ca88B8eF43564be3244bdd7163De04D",
  "settlementRef": { "chainId": 1, "txHash": "0x779204…a94bd" },
  "verdictHash": "0xdc568bd1…cfdd48f7",
  "result": { "resultText": "…", "resultHash": "0x0f28cc02…68eb42b7" },
  "publishesLosses": true,
  "recordPointer": "…/proof"
}
```

Pay-on-delivery ⇒ **OutcomeAttestation only** (attestor signs post-outcome); there is no pre-outcome `OutcomeCommitment`, so `anchor.establishes` is existence-only, not pre-outcome ordering.

## Reference deployment

- **Ethereum mainnet** — [`0x7057fbA75Ca88B8eF43564be3244bdd7163De04D`](https://etherscan.io/address/0x7057fbA75Ca88B8eF43564be3244bdd7163De04D) (verified). Live example settlement: release tx `0x779204…a94bd`.
- Also live in the [onchain-boiler-kit](https://github.com/trustless-ai/onchain-boiler-kit) settlement tab (deploy + monitor).

## Tests

`test/settlement/ConsultEscrow/ConsultEscrow.t.sol` — happy-path release, wrong-signer revert, **job-id binding** (the fix), refund after / before deadline, and double-release guard. Run with `forge test` (requires `forge install foundry-rs/forge-std`).

## Relationship to ERC-8203

[ERC-8203 (Agent Off-Chain Conditional Settlement, magicians #28041)](https://ethereum-magicians.org/t/28041) is an **off-chain / state-channel** settlement spec (`ConditionalLock` + `SettlementProofRef`, happy-path off-chain, on-chain only on dispute). `ConsultEscrow` is the complementary **on-chain-custody, attestor-signed, pay-on-delivery** shape: it does not implement the 8203 state-channel lifecycle. A custodial ledger built on top MAY shape its receipts to 8203's `RECEIPT_ROOT` / `SettlementProofRef` so a balance can be settled on-chain via an 8203 proof if a platform misbehaves — an alignment seam, not an implementation claim.

## Related ERCs

- [ERC-8299 (WYRIWE)](../../verify/ERC8299) — the result commitment the attestor signs is a WYRIWE result hash.
- [ERC-8004](../../identity/ERC8004) — `provider` / `attestor` resolve from agent identity.
