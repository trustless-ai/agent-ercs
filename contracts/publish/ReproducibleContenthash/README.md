# Reproducible Contenthash Commitment

- **Spec**: draft — ERC number not yet assigned
- **Discussion**: pending (Ethereum Magicians thread to open)
- **Reference implementation**: [trustless-ai/cross-reference-console](https://github.com/trustless-ai/cross-reference-console) — `reference/verify_pin.py`, `reference/sign_confirmation.py`, `PIN-RECORD.md`; the off-chain form of this rule, already producing signed confirmations in the shape this interface consumes
- **Status**: Draft
- **Authors**: Tiago Merlini Ferrão (@TMerlini); co-authors open

The `publish/` corner. Where the rest of this repo verifies what an agent *did*,
this constrains what a name *says* — the last mile, and the one link in the chain
that is not recomputable.

## The problem it closes

The ENS `contenthash` is a transaction someone sent, pointing at bytes they chose.
Every other value a reader might check is derivable from primary sources; this one
is not. If the published page renders a registry, a proof set or an audit result,
whoever controls it controls what the world believes that data says.

Three failure modes motivated this, all met in practice rather than imagined:

1. **A published page corresponding to no commit** — hand-built and copied into a
   publish directory, so its CID could not be checked by anyone, including its
   publisher.
2. **A CID irreproducible even from the right source** — the build embedded
   wall-clock time, so two builds of one commit differed. Reproducibility is a
   precondition for any multi-party check.
3. **Identical bytes producing different CIDs** — `ipfs add` derives a CID from the
   content *and* its own parameters. Two honest parties rebuilding the same commit
   report different CIDs if their flags differ, and each concludes the other erred.

## Interfaces

| File | Role |
|------|------|
| `IReproducibleContenthash.sol` | `commit` with confirmations, `threshold`, `isSigner`, `sequence` |

## Design notes worth arguing with

**`treeHash` and `cid` are separate on purpose.** `treeHash` depends on the bytes
alone and is the authority on whether two rebuilds agree; `cid` depends on bytes
*and* parameters and is what gets published. Two parties matching on `treeHash`
but not `cid` have found a **parameter disagreement** — nothing is wrong with the
content. Reporting that as a mismatch teaches operators to distrust the alarm.

**The signature covers the whole confirmation, never an enumerated subset.** A
hand-maintained list of covered fields must be updated whenever a field is added,
and nothing fails when someone forgets — the new field then sits outside the
signature while consuming logic acts on it. This is not hypothetical: it happened
twice in the reference implementation, the second time in the very commit that
fixed the first.

**A threshold, not a delegate list.** Authorising more addresses improves
availability by multiplying the paths to a unilateral publish. The threshold keeps
"no single party decides" while still removing the single-operator bottleneck.

**Confirmation signing is decoupled from any attestation scheme the publisher
already uses.** A party may sign attestations under a scheme the EVM cannot verify
cheaply (BIP-340, for instance). A pin confirmation is a different statement and
need not share a scheme; requiring it to would exclude such parties for no gain.

## Security note that generalises past this ERC

Verifying a source-built artifact means running the source's own build. **If the
record names the repository, anyone who can author a record can execute code on
every verifier** — and verifiers are exactly the participants doing the most
careful work. Permitted sources MUST be fixed by the verifier, never read from the
artifact being verified.

The contract MUST hold only the ENS **registry owner** role, never the registrar
deed. Retaining the deed preserves `BaseRegistrar.reclaim()` as an unconditional
escape hatch; a contract that holds the deed and cannot update is indistinguishable
from a burned name.
