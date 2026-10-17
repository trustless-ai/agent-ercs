#!/usr/bin/env python3
"""Generates verify-outcome-v0.vectors.json: pinned vectors for ERC-8275
IAgentReputation.verifyOutcome(orderId, proof).

Every vector carries the order being scored, the proof as presented, and a `chain` fixture that
stands in for eth_getTransactionReceipt / eth_getBlockByNumber on each chainId the verifier can
reach. The fixture is the CHAIN's answer, never the presenter's: a live adapter replaces it with
RPC calls and nothing else changes. Addresses, hashes and amounts are deterministic (sha256 of a
fixed label), so the file is reproducible byte for byte. Stdlib only.

Event topics are pinned literals (keccak256 is not in the Python stdlib). Recompute them with
`cast keccak "Released(bytes32,bytes32,bytes32,address,uint256)"` and
`cast keccak "Transfer(address,address,uint256)"`.

Run: python3 generate_vectors.py > verify-outcome-v0.vectors.json
"""
import hashlib
import json

# keccak256("Released(bytes32,bytes32,bytes32,address,uint256)"), the release event of
# contracts/settlement/ConsultEscrow/IConsultEscrow.sol, here emitted by an ERC-20 escrow.
RELEASED_TOPIC = "0x663f64891c2ac78fab8caeb1048364c51e6946d12f34e3431f7ced91032c1eb5"
# keccak256("Transfer(address,address,uint256)")
TRANSFER_TOPIC = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
# win_rate.bps.v0, published on the reference feed as winRateBpsGoverningConventionHash.
WIN_RATE_CONVENTION = "0x0501b75db8e9ef4ef67c74efcfbe2a200b0a7e5aea5ca62f778c91c119e68daf"
CHAIN_ID = 8453  # Base; any EVM chainId works the same way


def h32(label: str) -> str:
    return "0x" + hashlib.sha256(f"verify-outcome-v0:{label}".encode()).hexdigest()


def addr(label: str) -> str:
    return h32(label)[:42]


def word_addr(a: str) -> str:
    return "0x" + a[2:].rjust(64, "0")


def word_int(n: int) -> str:
    return "0x" + format(n, "064x")


ESCROW = addr("escrow")
ASSET = addr("usdc")
PROVIDER = addr("provider")
OTHER = addr("someone-else")
ORDER_ID = h32("order-1")
OTHER_ORDER_ID = h32("order-2")
AMOUNT = 2_500_000  # 2.50 USDC at 6 decimals


def released_log(log_index, order_id, provider, amount, escrow=ESCROW):
    result_hash = h32(f"result:{order_id}")
    commitment = h32(f"commitment:{order_id}")
    data = "0x" + "".join(w[2:] for w in (result_hash, commitment, word_addr(provider), word_int(amount)))
    return {"logIndex": log_index, "address": escrow, "topics": [RELEASED_TOPIC, order_id], "data": data}


def transfer_log(log_index, frm, to, amount, asset=ASSET):
    return {"logIndex": log_index, "address": asset,
            "topics": [TRANSFER_TOPIC, word_addr(frm), word_addr(to)], "data": word_int(amount)}


def receipt(tx, block, status, logs):
    return {"transactionHash": tx, "blockNumber": block, "status": status, "logs": logs}


ORDER = {"orderId": ORDER_ID, "chainId": CHAIN_ID, "escrow": ESCROW, "asset": ASSET,
         "provider": PROVIDER, "amount": str(AMOUNT)}
TX_GOOD = h32("tx:release-order-1")
BLOCK = 21_000_000


def chain_with(*receipts_, block_txs=None):
    rs = {r["transactionHash"]: r for r in receipts_}
    blocks = {}
    for r in receipts_:
        blocks.setdefault(str(r["blockNumber"]), []).append(r["transactionHash"])
    if block_txs:
        blocks.update(block_txs)
    return {str(CHAIN_ID): {"receipts": rs, "blocks": blocks}}


def proof(tx=TX_GOOD, log_index=0, chain_id=CHAIN_ID, conv=WIN_RATE_CONVENTION,
          transfer_log_index=1):
    return {"chainId": chain_id, "txHash": tx, "releaseLogIndex": log_index,
            "transferLogIndex": transfer_log_index,
            "governing_convention_hash": conv}


GOOD_RECEIPT = receipt(TX_GOOD, BLOCK, 1, [
    released_log(0, ORDER_ID, PROVIDER, AMOUNT),
    transfer_log(1, ESCROW, PROVIDER, AMOUNT),
])


def vec(name, note, expected, prf, chain, order=ORDER):
    return {"name": name, "note": note, "order": order, "proof": prf, "chain": chain,
            "expected": {"outcome": expected}}


def build():
    v = []
    v.append(vec(
        "positive-release-matches-order",
        "Release event for this orderId at the proven logIndex, emitted by the order's escrow, and an "
        "asset Transfer escrow -> provider for the order amount in the SAME receipt, status 1.",
        "verified", proof(), chain_with(GOOD_RECEIPT)))

    v.append(vec(
        "facilitator-report-only-no-tx",
        "The x402#3824 shape (Petchevere): a facilitator-signed report says 'settled' but carries no "
        "transaction to recompute from. The report is the presenter's word, not chain evidence.",
        "rejected",
        {"chainId": CHAIN_ID, "governing_convention_hash": WIN_RATE_CONVENTION,
         "facilitatorReport": {"orderId": ORDER_ID, "status": "settled", "payee": PROVIDER,
                               "amount": str(AMOUNT), "txHash": None,
                               "signature": h32("facilitator-sig") + h32("facilitator-sig-2")[2:]}},
        chain_with(GOOD_RECEIPT)))

    tx_other = h32("tx:release-order-2")
    v.append(vec(
        "valid-tx-for-different-order",
        "A real, successful release with a real Transfer to the same provider for the same amount, "
        "but the release event is for a DIFFERENT orderId. Reusing one settlement for two orders.",
        "rejected", proof(tx=tx_other),
        chain_with(receipt(tx_other, BLOCK, 1, [
            released_log(0, OTHER_ORDER_ID, PROVIDER, AMOUNT),
            transfer_log(1, ESCROW, PROVIDER, AMOUNT)]))))

    tx_amt = h32("tx:release-short")
    v.append(vec(
        "amount-mismatch",
        "Release for this orderId and a Transfer to the provider, but for less than the order amount "
        "(both the event and the Transfer agree with each other, not with the order).",
        "rejected", proof(tx=tx_amt),
        chain_with(receipt(tx_amt, BLOCK, 1, [
            released_log(0, ORDER_ID, PROVIDER, AMOUNT - 1),
            transfer_log(1, ESCROW, PROVIDER, AMOUNT - 1)]))))

    tx_payee = h32("tx:release-wrong-payee")
    v.append(vec(
        "payee-mismatch",
        "Release for this orderId for the right amount, but paid to an address that is not the "
        "order's provider.",
        "rejected", proof(tx=tx_payee),
        chain_with(receipt(tx_payee, BLOCK, 1, [
            released_log(0, ORDER_ID, OTHER, AMOUNT),
            transfer_log(1, ESCROW, OTHER, AMOUNT)]))))

    tx_rev = h32("tx:release-reverted")
    v.append(vec(
        "reverted-tx",
        "Receipt status 0. A conforming node returns no logs for a reverted transaction; this "
        "fixture keeps them (as a lax indexer or relay might report the attempted call) so a checker "
        "that skips the status check is caught rather than saved by the empty log list.",
        "rejected", proof(tx=tx_rev),
        chain_with(receipt(tx_rev, BLOCK, 0, [
            released_log(0, ORDER_ID, PROVIDER, AMOUNT),
            transfer_log(1, ESCROW, PROVIDER, AMOUNT)]))))

    tx_rel = h32("tx:release-no-transfer")
    tx_xfer = h32("tx:unrelated-transfer")
    v.append(vec(
        "transfer-in-other-tx-same-block",
        "The proven tx carries the release event but no asset Transfer; the matching Transfer "
        "(escrow -> provider, exact amount) sits in a different tx in the same block. Logs come from "
        "the proven receipt only, never from a scan of the block.",
        "rejected", proof(tx=tx_rel),
        chain_with(
            receipt(tx_rel, BLOCK, 1, [released_log(0, ORDER_ID, PROVIDER, AMOUNT)]),
            receipt(tx_xfer, BLOCK, 1, [transfer_log(0, ESCROW, PROVIDER, AMOUNT)]))))

    zero_order = dict(ORDER, amount="0")
    tx_zero = h32("tx:release-zero-no-transfer-data")
    nodata = transfer_log(1, ESCROW, PROVIDER, 0)
    del nodata["data"]
    v.append(vec(
        "transfer-missing-data",
        "A Transfer log escrow -> provider with no data field, against an order whose amount is 0. "
        "The Transfer amount is required (exactly one 32-byte word); a checker that reads missing "
        "data as 0 would bind a zero-amount order to a log that proves no amount (raised by Panini).",
        "rejected", proof(tx=tx_zero),
        chain_with(receipt(tx_zero, BLOCK, 1, [
            released_log(0, ORDER_ID, PROVIDER, 0), nodata])),
        order=zero_order))

    v.append(vec(
        "chainid-as-decimal-string",
        "The same proof as the positive vector, with chainId carried as the string \"8453\" against "
        "an order carrying the integer 8453. chainId compares by value after normalizing (JSON "
        "integer, decimal string, or 0x hex as eth_chainId returns it), not by JSON type (raised by "
        "Panini).",
        "verified", dict(proof(), chainId=str(CHAIN_ID)), chain_with(GOOD_RECEIPT)))

    v.append(vec(
        "chain-unreachable",
        "Echo's tri-state case: the verifier has no view of chainId (wrong network, no RPC). The "
        "proof may be sound; nothing was checked, so it is neither accepted nor rejected.",
        "unverifiable", proof(), {}))

    v.append(vec(
        "receipt-not-retrievable",
        "The chain is reachable but the receipt for txHash is not available (pruned history, "
        "unindexed tx). Same tri-state answer as an unreachable chain.",
        "unverifiable", proof(), chain_with(block_txs={str(BLOCK): [TX_GOOD]})))

    tx_idx = h32("tx:release-transfer-index-mismatch")
    v.append(vec(
        "transfer-index-mismatch",
        "The receipt carries both a release and a matching Transfer, but the proof names the "
        "release's own logIndex as transferLogIndex. The proof must NAME the payment it relies on; "
        "a checker that searches for any matching Transfer instead would accept this.",
        "rejected", proof(tx=tx_idx, transfer_log_index=0),
        chain_with(receipt(tx_idx, BLOCK, 1, [
            released_log(0, ORDER_ID, PROVIDER, AMOUNT),
            transfer_log(1, ESCROW, PROVIDER, AMOUNT)]))))

    tx_batch = h32("tx:batch-two-releases-one-transfer")
    v.append(vec(
        "two-releases-one-transfer",
        "A batch receipt releases TWO orders to the same provider for the same amount but carries "
        "only ONE Transfer. Both proofs can name that same log, so naming alone is not enough: the "
        "receipt must carry at least as many matching payments as matching releases, or one payment "
        "mints two settled outcomes and two reputation increments (raised by Tiago/Echo).",
        "rejected", proof(tx=tx_batch, log_index=1, transfer_log_index=2),
        chain_with(receipt(tx_batch, BLOCK, 1, [
            released_log(0, ORDER_ID, PROVIDER, AMOUNT),
            released_log(1, OTHER_ORDER_ID, PROVIDER, AMOUNT),
            transfer_log(2, ESCROW, PROVIDER, AMOUNT)])),
        order=dict(ORDER, orderId=OTHER_ORDER_ID)))

    other_conv = h32("some-other-rounding-convention")
    v.append(vec(
        "governing-convention-hash-mismatch",
        "The settlement recomputes cleanly, but the proof was scored under a different "
        "governing_convention_hash than the one this verifier scores winRate under. The outcome is "
        "unverifiable FOR THAT SCORE; it is not re-scored under the verifier's own convention.",
        "unverifiable", proof(conv=other_conv), chain_with(GOOD_RECEIPT)))
    return v


def main():
    out = {
        "profile": "verify_outcome.v0",
        "description": "Pinned semantics for ERC-8275 IAgentReputation.verifyOutcome(orderId, proof): "
                       "a settled outcome counts toward reputation only if any verifier can recompute "
                       "it from the chain, never from the facilitator's report. Tri-state, fail-closed.",
        "constants": {"releasedTopic": RELEASED_TOPIC, "transferTopic": TRANSFER_TOPIC,
                      "governingConventionHash": WIN_RATE_CONVENTION,
                      "governingConvention": "win_rate.bps.v0"},
        "outcomes": ["verified", "rejected", "unverifiable"],
        "vectors": build(),
    }
    print(json.dumps(out, indent=2))


if __name__ == "__main__":
    main()
