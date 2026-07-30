#!/usr/bin/env python3
"""Generates attester-diversity-v0.vectors.json — deterministic, fixed-seed synthetic key
material over a hand-pinned block structure (K blocks = K true attester-operators, each block's
attestations issued from multiple distinct signing keys but one real operator).

The SCORED quantity (attestationCount_effective, via N_eff = 1 / sum(share_i^2)) is a pure
function of each block's share of total attestations -- it is fully deterministic given the
block structure and carries no randomness. The fixed seed here is used only to generate
presentable, distinct-looking signing-key identifiers per attestation (cosmetic realism for the
fixture, not load-bearing for the scored value), so the vectors are reproducible byte-for-byte
on any machine.

Run: python3 generate_vectors.py > attester-diversity-v0.vectors.json
"""
import hashlib
import json
import random

SEED = 8275  # fixed, matches the ERC number this suite conforms to -- reproducible, not secret
rng = random.Random(SEED)


def fake_key(label: str) -> str:
    """Deterministic 32-byte hex 'signing key id' for a given (seeded) label."""
    salt = rng.getrandbits(64).to_bytes(8, "big")
    return "0x" + hashlib.sha256(label.encode() + salt).hexdigest()


def build_block_vector(name, note, blocks, agent_id):
    """blocks: list of (operator_label, attestation_count). Each attestation gets its own
    distinct signing key (so naive attestationCount always equals the raw total), but keys
    within a block share `trueOperator` (what an ERC-8294 operator-diversity claim would report)."""
    log = []
    for op_label, count in blocks:
        operator_id = "0x" + hashlib.sha256(f"operator:{op_label}".encode()).hexdigest()[:40]
        for i in range(count):
            log.append({
                "eventId": fake_key(f"{name}:{op_label}:{i}"),
                "attesterKey": fake_key(f"{name}:{op_label}:{i}:key"),
                "trueOperator": operator_id,
                "sigValid": True,
            })
    total = len(log)
    shares = {}
    for op_label, count in blocks:
        operator_id = "0x" + hashlib.sha256(f"operator:{op_label}".encode()).hexdigest()[:40]
        shares[operator_id] = shares.get(operator_id, 0) + count / total
    n_eff = 1.0 / sum(s * s for s in shares.values())
    return {
        "name": name,
        "note": note,
        "agentId": agent_id,
        "log": log,
        "expected": {
            "attestationCountRaw": total,
            "attestationCountEffective": round(n_eff, 6),
        },
    }


AGENT = "0x" + hashlib.sha256(b"attester-diversity-v0:demo-agent").hexdigest()[:40]

vectors = [
    build_block_vector(
        "single-operator-sybil-ring",
        "THE COUNTEREXAMPLE. 5 distinct signing keys, 5 distinct valid signatures -- today's "
        "spec would report attestationCount=5. All 5 keys trace to ONE true operator (a Sybil "
        "ring of verifiers, not of the attested agent). Diversity-weighted count collapses to "
        "N_eff=1, the honest answer: one independent judgment, wearing five keys.",
        [("operator-A", 5)],
        AGENT,
    ),
    build_block_vector(
        "three-independent-operators-even",
        "3 genuinely distinct operators, 4 attestations each (12 total, evenly spread). "
        "N_eff = K = 3 -- diversity-weighted count matches the raw operator count exactly when "
        "attestation weight is evenly distributed across independent attesters.",
        [("operator-A", 4), ("operator-B", 4), ("operator-C", 4)],
        AGENT,
    ),
    build_block_vector(
        "skewed-diversity",
        "One dominant operator (8 of 12 attestations) plus two minor independent ones (2 each). "
        "Real, partial diversity: N_eff sits between the single-Sybil floor (1) and the "
        "fully-even ceiling (3), correctly reflecting that most weight still traces to one "
        "source even though 3 distinct operators are technically represented.",
        [("operator-A", 8), ("operator-B", 2), ("operator-C", 2)],
        AGENT,
    ),
    build_block_vector(
        "single-attestation",
        "Trivial floor case: exactly one attestation, one operator. N_eff=1 by construction, "
        "not a special case in the formula -- it falls out of 1/sum(share_i^2) with a single "
        "share of 1.0.",
        [("operator-A", 1)],
        AGENT,
    ),
    build_block_vector(
        "five-operators-one-outlier",
        "5 operators total: one large Sybil-suspect cluster (10 attestations from operator-A, "
        "structurally identical to the counterexample above) alongside 4 genuinely independent "
        "single-attestation operators. N_eff correctly stays low (dominated by the 10-share "
        "block) rather than being pulled toward 5 by the presence of minor independent voices.",
        [("operator-A", 10), ("operator-B", 1), ("operator-C", 1), ("operator-D", 1), ("operator-E", 1)],
        AGENT,
    ),
]

out = {
    "profile": "attester_diversity.v0",
    "seed": SEED,
    "description": (
        "Diversity-weighted attestationCount for ERC-8275's reputation axis "
        "(f(attestationCount, counterpartyDiversity, winRate, volumeCap)), closing the gap "
        "Dipankar Sarkar raised: signature-gating alone stops the ATTESTED party from "
        "self-inflating attestationCount, but does nothing to stop N distinct, validly-signed "
        "attestations tracing back to M << N actual attester-operators -- a Sybil ring of "
        "VERIFIERS, not of the attested address. attestationCount_effective replaces (or "
        "accompanies) the raw signature-valid count: given share_i = operator i's fraction of "
        "an agent's total attestation weight (sourced from a composing ERC-8294 network's "
        "operator-diversity claims, the same source counterpartyDiversity already consumes), "
        "attestationCount_effective = 1 / sum(share_i^2) -- the standard inverse-Simpson / "
        "inverse-HHI effective-number-of-players formula. Collapses to 1 when every attestation "
        "traces to one operator regardless of raw count; equals K when evenly spread across K "
        "independent operators. Where no composing 8294 network exists (a single-issuer "
        "reference feed), attestationCount_effective trivially equals 1 -- an honest, "
        "conservative floor, not a special case requiring separate logic."
    ),
    "recompute": (
        "shares = {op: sum(1 for e in log if e.trueOperator == op and e.sigValid) / "
        "sum(1 for e in log if e.sigValid) for op in distinct_operators(log)} ; "
        "attestationCountEffective = 1 / sum(s**2 for s in shares.values())"
    ),
    "vectors": vectors,
}

print(json.dumps(out, indent=2))
