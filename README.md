# Agent ERCs

Solidity interfaces and base implementations for the **trustless AI agent economy**. Part of the [Trustless AI](https://github.com/trustless-ai) ecosystem — owned by no one, open to everyone.

This repository is the on-chain standard library for AI agents: interfaces you implement once to run across any conformant protocol, and base implementations you inherit to get production-ready behavior out of the box.

---

## Directory Structure

```
contracts/
├── <category>/              # Functional domain (e.g., identity, execution, verify)
│   └── <ERCXXXX>/           # One directory per ERC
│       ├── I*.sol           # Interface(s) defined by the spec
│       ├── <Name>.sol       # Base implementation (when ready)
│       └── README.md        # Spec links, discussion, interface inventory
├── interfaces/              # Cross-domain shared interfaces (e.g., IERC165)
├── utils/                   # Shared utility contracts
└── mocks/                   # Mock contracts for testing

test/
└── <category>/              # Tests mirror contracts/ exactly
    └── <ERCXXXX>/
```

No top-level `src/`, no flat file dump — every ERC lives in its own directory under a functional category. Pick the category that best describes the **link** your ERC defends (e.g., `identity/` for agent registration, `execution/` for task dispatch and orchestration, `verify/` for cryptographic proof verification, `provenance/` for input/output commitment, `eligibility/` for access control and permissions…) and create `contracts/<category>/<ERCXXXX>/`. If nothing fits, propose a new category in your PR — categories emerge from the stack.

---

## Code Classification

Every `.sol` file in this repository falls into exactly one of these categories:

| Type | Definition | Production-ready | Where |
|------|-----------|:---:|--------|
| **Interface** | Method signatures, structs, enums defined by the ERC specification | ✅ Must implement | `agent-ercs` |
| **Base Implementation** | Inheritable, audited production contract that implements the interface | ✅ Can inherit for production | `agent-ercs` |
| **Example / Reference** | Demonstrates how to use the interface; not audited | ❌ Do not use in production | Other repositories |

**Base implementations are not examples.** A base implementation is audited (or on a clear path to audit), follows security best practices, and is safe to inherit in production contracts. Examples and reference implementations belong in separate repositories (project repos, `agent-sdk`, etc.) — they show developers *how* to use the interface but haven't been hardened for production.

---

## The Rule

> Nothing goes in that a third party can't independently verify from public data.

Every contract in this repository must be recomputable — anyone with access to the chain and the spec should be able to reproduce and verify every outcome, without trusting any individual contributor or organization.

---

## Setup

```bash
# Install dependencies
forge install OpenZeppelin/openzeppelin-contracts

# Build
forge build

# Test
forge test
```

---

## Contributing

There are many ways to get involved — no commitment needed to start.

### 💬 Join the conversation

Hop into the [Telegram group](https://t.me/+rKbR1EQcT8QxNzI0) to brainstorm, ask questions, or just see what people are working on. This is the best first step if you're not sure where to start.

### 🐛 Report a bug or improve something

Found an issue in an interface, a spec inconsistency, or a gap in the docs? [Open an issue](https://github.com/trustless-ai/agent-ercs/issues) or send a PR. Bug reports, test contributions, and documentation improvements all count.

### 📐 Submit your ERC

Have an ERC that fits the trustless AI stack? Here's how to get it into `agent-ercs`:

1. **Pick a category** — which functional domain does your ERC defend? Create `contracts/<category>/<ERCXXXX>/`.
2. **Add the interface** — extract the Solidity interface from your ERC spec into `I*.sol` files. Follow the `pragma solidity ^0.8.0` convention.
3. **Write a README** — include the spec link, magician discussion link, interface inventory, and how it relates to other ERCs in the stack. See existing ERC directories for the format.
4. **Add tests** — tests go in `test/<category>/<ERCXXXX>/`, mirroring the contracts structure.
5. **Open a PR** — we review fast. If your ERC is still a Draft, that's fine — interfaces evolve with the spec.

If your ERC also has a **base implementation** that is audited (or on a clear audit path), include it in the same directory. If it's a reference implementation or example, put it in a separate repository.

> You keep full control of your ERC. This repository is a shared home, not a gate.

---

## License

Apache 2.0 — see [LICENSE](./LICENSE).
