// attester_diversity.v0 — diversity-weighted attestationCount for ERC-8275's reputation axis.
//
// The gap this closes (Dipankar Sarkar, eth-magicians t/28275-family thread): attestationCount
// is signature-gated (only distinct, sig-valid event_ids count) so the ATTESTED party can't
// self-inflate it -- but nothing stops N distinct, validly-signed attestations from tracing back
// to M << N actual attester-OPERATORS (a Sybil ring of verifiers, not of the attested address).
// The conserved carrier here is OPERATOR-weighted diversity, not a flat count of sig-valid
// events -- the same "attribution is a label, never the aggregate" discipline as
// aggregate-budget-v0's root-keyed sum vs per-edge subtotal.
//
// Correct method: group attestations by trueOperator (sourced from a composing ERC-8294
// network's operator-diversity claims), compute each operator's share of total attestation
// weight, then attestationCountEffective = 1 / sum(share_i^2) -- inverse-Simpson / inverse-HHI.
// Wrong (the counterexample method, --tamper): count every distinct sig-valid event_id as
// independent, ignoring trueOperator entirely -- exactly today's un-diversity-weighted spec text,
// and exactly what a Sybil ring of verifier keys walks straight past.
//
// Adapter contract for bin/conformance-suite: fixture JSON on stdin -> {name: result} on stdout.

type Attestation = { eventId: string; attesterKey: string; trueOperator: string; sigValid: boolean };
type Vector = { name: string; agentId: string; log: Attestation[]; expected: unknown };

function operatorShares(log: Attestation[]): Map<string, number> {
  const valid = log.filter((e) => e.sigValid);
  const counts = new Map<string, number>();
  for (const e of valid) counts.set(e.trueOperator, (counts.get(e.trueOperator) ?? 0) + 1);
  const total = valid.length;
  const shares = new Map<string, number>();
  for (const [op, n] of counts) shares.set(op, n / total);
  return shares;
}

// Correct: diversity-weighted effective count.
function attestationCountEffective(log: Attestation[]): number {
  const shares = operatorShares(log);
  let sumSq = 0;
  for (const s of shares.values()) sumSq += s * s;
  return sumSq > 0 ? 1 / sumSq : 0;
}

// Wrong (the counterexample method): raw distinct sig-valid event count, ignoring trueOperator.
// This is exactly the un-weighted `attestationCount` the current spec text defines -- a Sybil
// ring of verifier keys inflates this arbitrarily while attestationCountEffective stays pinned
// at the true operator count.
function attestationCountRawNaive(log: Attestation[]): number {
  return log.filter((e) => e.sigValid).length;
}

function valueFor(v: Vector, tamper: boolean): { attestationCountRaw: number; attestationCountEffective: number } {
  const raw = attestationCountRawNaive(v.log);
  const eff = tamper ? raw : attestationCountEffective(v.log); // tamper: report raw as if it were the diversity-weighted value
  return { attestationCountRaw: raw, attestationCountEffective: Math.round(eff * 1e6) / 1e6 };
}

if (import.meta.main) {
  const tamper = Bun.argv.includes("--tamper");
  if (Bun.argv.includes("--grade")) {
    const fx = JSON.parse(await Bun.stdin.text());
    const out: Record<string, unknown> = {};
    for (const v of fx.vectors as Vector[]) out[v.name] = valueFor(v, tamper);
    console.log(JSON.stringify(out));
    process.exit(0);
  }
  // Standalone self-check: recompute each vector and diff against its pinned expected.
  const fx = JSON.parse(await Bun.file(`${import.meta.dir}/attester-diversity-v0.vectors.json`).text());
  let fails = 0;
  for (const v of fx.vectors as Vector[]) {
    const got = valueFor(v, tamper);
    const ok = JSON.stringify(got) === JSON.stringify(v.expected);
    if (!ok) fails++;
    console.log(
      `${ok ? "✓" : "✗"} ${v.name.padEnd(34)} raw=${String(got.attestationCountRaw).padStart(3)} ` +
      `effective=${String(got.attestationCountEffective).padStart(8)}`
    );
  }
  console.log(
    `${fx.vectors.length - fails}/${fx.vectors.length} reproduced` +
    `${tamper ? " (tamper: naive raw-count-as-diversity method — mismatches on non-single-operator vectors are expected)" : ""}`
  );
  process.exit(fails ? 1 : 0);
}
