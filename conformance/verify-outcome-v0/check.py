#!/usr/bin/env python3
"""verify_outcome.v0 checker for ERC-8275 IAgentReputation.verifyOutcome(orderId, proof). Stdlib only.

verify(order, proof, chain, convention) returns one of three outcomes and fails closed:
  verified      the settlement recomputes from the chain alone and matches the order
  rejected      chain evidence is absent or contradicts the order
  unverifiable  the verifier could not look (chain unreachable, receipt not retrievable), or the
                proof was scored under a different governing_convention_hash. Never collapsed
                into verified or rejected.

`chain` is the chain's answer keyed by chainId: {"receipts": {txHash: receipt}, "blocks": {...}}.
A live adapter swaps it for eth_getTransactionReceipt on an RPC for that chainId.

  python3 check.py               reference checker against the pinned vectors (exit 1 on any miss)
  python3 check.py --mutants     every lax checker below must miss at least one vector
  python3 check.py --mutant NAME run one lax checker (prints where it diverges)
  python3 check.py --grade       adapter: fixture JSON on stdin -> {name: {"outcome": ...}} on stdout
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
VECTORS = os.path.join(HERE, "verify-outcome-v0.vectors.json")

VERIFIED, REJECTED, UNVERIFIABLE = "verified", "rejected", "unverifiable"
RELEASED_TOPIC = "0x663f64891c2ac78fab8caeb1048364c51e6946d12f34e3431f7ced91032c1eb5"
TRANSFER_TOPIC = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
WIN_RATE_CONVENTION = "0x0501b75db8e9ef4ef67c74efcfbe2a200b0a7e5aea5ca62f778c91c119e68daf"

# Lax checkers used as mutation controls. Each drops exactly one rule.
MUTANTS = {
    "trust-facilitator-report": "accepts a facilitator 'settled' report when no tx is given",
    "no-order-binding": "does not check the release event's orderId topic",
    "no-amount-check": "does not compare the paid amount with the order",
    "no-payee-check": "does not compare the payee with the order's provider",
    "ignore-status": "does not check receipt status",
    "scan-block-for-transfer": "accepts a matching Transfer anywhere in the block",
    "unverifiable-as-rejected": "binary checker: anything it cannot check is rejected",
    "unverifiable-as-verified": "binary checker: anything it cannot check is accepted",
    "ignore-convention-hash": "does not compare governing_convention_hash",
}


def _addr_from_word(word: str) -> str:
    return "0x" + word[-40:].lower()


def _words(data: str):
    d = data[2:] if data.startswith("0x") else data
    return ["0x" + d[i:i + 64] for i in range(0, len(d), 64)]


def _eq(a, b) -> bool:
    return isinstance(a, str) and isinstance(b, str) and a.lower() == b.lower()


def verify(order, proof, chain, convention=WIN_RATE_CONVENTION, mutant=None):
    """Returns (outcome, reason)."""
    tx = proof.get("txHash")
    if not tx:
        if mutant == "trust-facilitator-report":
            rep = proof.get("facilitatorReport") or {}
            if rep.get("status") == "settled" and _eq(rep.get("orderId"), order["orderId"]):
                return VERIFIED, "facilitator report trusted"
        return REJECTED, "no transaction to recompute from"
    if proof.get("chainId") != order["chainId"]:
        return REJECTED, "proof chainId differs from the order's"

    def cannot_check(reason):
        if mutant == "unverifiable-as-rejected":
            return REJECTED, reason
        if mutant == "unverifiable-as-verified":
            return VERIFIED, reason
        return UNVERIFIABLE, reason

    view = chain.get(str(order["chainId"]))
    if view is None:
        return cannot_check("chainId not reachable")
    rcpt = view.get("receipts", {}).get(tx)
    if rcpt is None:
        return cannot_check("receipt not retrievable")

    if rcpt.get("status") != 1 and mutant != "ignore-status":
        return REJECTED, "receipt status is not success"

    # Logs come from this receipt only.
    logs = list(rcpt.get("logs", []))
    rel = next((l for l in logs if l.get("logIndex") == proof.get("releaseLogIndex")), None)
    if rel is None or not _eq(rel.get("address"), order["escrow"]) or \
            not rel.get("topics") or not _eq(rel["topics"][0], RELEASED_TOPIC):
        return REJECTED, "no release event from the order's escrow at releaseLogIndex"
    if mutant != "no-order-binding" and (len(rel["topics"]) < 2 or not _eq(rel["topics"][1], order["orderId"])):
        return REJECTED, "release event is for a different orderId"
    w = _words(rel.get("data", ""))
    if len(w) != 4:
        return REJECTED, "malformed release event data"
    rel_payee, rel_amount = _addr_from_word(w[2]), int(w[3], 16)
    want_amount = int(order["amount"])
    if mutant != "no-payee-check" and not _eq(rel_payee, order["provider"]):
        return REJECTED, "release payee is not the order's provider"
    if mutant != "no-amount-check" and rel_amount != want_amount:
        return REJECTED, "release amount differs from the order"

    pool = logs
    if mutant == "scan-block-for-transfer":
        pool = []
        for t in view.get("blocks", {}).get(str(rcpt.get("blockNumber")), []):
            pool += view["receipts"].get(t, {}).get("logs", [])

    def transfer_ok(l):
        t = l.get("topics") or []
        if len(t) != 3 or not _eq(t[0], TRANSFER_TOPIC) or not _eq(l.get("address"), order["asset"]):
            return False
        if not _eq(_addr_from_word(t[1]), order["escrow"]):
            return False
        if mutant != "no-payee-check" and not _eq(_addr_from_word(t[2]), order["provider"]):
            return False
        return mutant == "no-amount-check" or int(l.get("data", "0x0"), 16) == want_amount

    if not any(transfer_ok(l) for l in pool):
        return REJECTED, "no asset Transfer escrow -> provider for the order amount in this receipt"

    if mutant != "ignore-convention-hash" and not _eq(proof.get("governing_convention_hash"), convention):
        return UNVERIFIABLE, "proof scored under a different governing_convention_hash"
    return VERIFIED, "settlement recomputed from the chain"


def run(vectors, mutant=None, convention=WIN_RATE_CONVENTION):
    return {v["name"]: verify(v["order"], v["proof"], v["chain"], convention, mutant) for v in vectors}


def main(argv):
    if "--grade" in argv:
        fx = json.load(sys.stdin)
        conv = fx.get("constants", {}).get("governingConventionHash", WIN_RATE_CONVENTION)
        print(json.dumps({n: {"outcome": o} for n, (o, _) in run(fx["vectors"], convention=conv).items()}))
        return 0
    with open(VECTORS) as f:
        fx = json.load(f)
    vectors = fx["vectors"]
    want = {v["name"]: v["expected"]["outcome"] for v in vectors}

    if "--mutants" in argv:
        survivors = 0
        for m, desc in MUTANTS.items():
            got = run(vectors, m)
            missed = [n for n in want if got[n][0] != want[n]]
            if not missed:
                survivors += 1
            print(f"{'caught  ' if missed else 'SURVIVED'} {m:26} ({desc}) -> diverges on {', '.join(missed) or 'nothing'}")
        print(f"{len(MUTANTS) - survivors}/{len(MUTANTS)} lax checkers caught")
        return 1 if survivors else 0

    mutant = None
    if "--mutant" in argv:
        mutant = argv[argv.index("--mutant") + 1]
        if mutant not in MUTANTS:
            print(f"unknown mutant; one of: {', '.join(MUTANTS)}")
            return 2
    got = run(vectors, mutant)
    fails = 0
    for n, (o, reason) in got.items():
        ok = o == want[n]
        fails += not ok
        print(f"{'ok ' if ok else 'BAD'} {n:36} {o:13} {reason}")
    print(f"{len(got) - fails}/{len(got)} reproduced" + (f" (mutant {mutant}: a miss is expected)" if mutant else ""))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
