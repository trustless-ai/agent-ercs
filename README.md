<div align="center">
    <img width="3265" height="994" alt="e89e95aa8ed6a99833394682c6632cb7" src="https://github.com/user-attachments/assets/9ed2ab1a-aab5-4133-a5e2-5bcbdad0ffea" />
</div>

# Agent ERCs

Solidity interfaces and base implementations for the **trustless AI agents**.

This repo is a part of the [trustless-ai](https://github.com/trustless-ai) open-source ecosystem: A powerful, decentralized AI infrastructure that anyone can provide, anyone can use, and everyone can verify by recomputing the proof — owned by no one.

Let's build trustless AI — for everyone!

---

## ERCs Included

Import path pattern:

```solidity
import {InterfaceName} from "@agent-ercs/contracts/<category>/<ERCXXXX>/FileName.sol";
```

| ERC | Category | What it defines | Import path |
|-----|----------|-----------------|-------------|
| **ERC-8004** | `identity/` | Trustless agents — identity registration, reputation feedback, and validation requests | `identity/ERC8004/IIdentityRegistry.sol` |
| **ERC-8263** | `anchor/` | Onchain proof layer for AI agents — write-side action anchoring via a single canonical `AnchorProof` event | `anchor/ERC8263/IOnChainProof.sol` |
| **ERC-8274** | `verify/` | AI inference proof verification — three-layer decoupling of crypto proof, agent binding, and contract declaration | `verify/ERC8274/IAgentVerifier.sol` |
| **ERC-8299** | `verify/` | WYRIWE — input provenance attestation for AI inference | `verify/ERC8299/IWyriweAttestation.sol` |
| **ERC-8301** | `execution/` | AI agent execution — universal task dispatch, orchestration, and verifiable evidence chain | `execution/ERC8301/IAgentWorkflow.sol` |
| **ERC-8312** | `metering/` | Bounded agent actions — envelope registration and aggregate consumption metering against an accepted bound | `metering/ERC8312/IBoundedAgentAction.sol` |

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
