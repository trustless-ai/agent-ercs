# Agent ERCs

Standardized Solidity interfaces and base implementations for the **trustless AI agent economy**. Part of the [Trustless AI](https://github.com/trustless-ai) ecosystem.

```solidity
import {IAgentVerifier} from "@agent-ercs/contracts/verify/ERC8274/IAgentVerifier.sol";
import {IAgentWorkflow} from "@agent-ercs/contracts/execution/ERC8301/IAgentWorkflow.sol";
import {IIdentityRegistry} from "@agent-ercs/contracts/identity/ERC8004/IIdentityRegistry.sol";
```

---

## The Trustless AI Stack

Each ERC defends one invariant. Together they form an end-to-end recomputable chain:

| Link | Invariant it defends | Lives in | ERC |
|------|---------------------|----------|-----|
| identity | the agent is who it claims to be | `agent-ercs` | [ERC-8004](./contracts/identity/ERC8004/) |
| dispatch | the task reached the agent it was meant for | `agent-ercs` | [ERC-8301](./contracts/execution/ERC8301/) |
| provenance | the inputs/outputs are committed and intact | `agent-ercs` | ERC-8281 / OCP + ERC-8299 / WYRIWE |
| verify | the verdict was committed, intact, by the claimed key | `agent-ercs` | [ERC-8274](./contracts/verify/ERC8274/) |
| eligibility | the actor was permitted to act | `agent-ercs` | ReceiptOS |
| anchor | the commitment existed before its outcome | `agent-sdk` | ERC-8263 / TruthAnchorV1 |
| settlement | the outcome settled on a public, non-editable account | project repo | ERC-8275 (settlement axis) |
| reputation | standing is a deterministic function of public settled outcomes | `agent-sdk` | ERC-8275 (reputation axis) |

---

## Directory Structure

```
agent-ercs/
├── contracts/
│   ├── verify/          # Verification interfaces & base implementations
│   │   └── ERC8274/     # Each ERC gets its own subdirectory
│   │       ├── IProofVerifier.sol
│   │       ├── IAgentVerifier.sol
│   │       ├── IAgentVerifiable.sol
│   │       ├── AgentVerifier.sol      # Base implementation (when ready)
│   │       └── README.md
│   ├── execution/       # Agent dispatch & orchestration
│   │   └── ERC8301/
│   │       ├── IAgentWorkflow.sol
│   │       ├── AgentWorkflow.sol
│   │       └── README.md
│   ├── identity/        # Agent identity & trust registries
│   │   └── ERC8004/
│   │       ├── IIdentityRegistry.sol
│   │       ├── IReputationRegistry.sol
│   │       ├── IValidationRegistry.sol
│   │       ├── IdentityRegistry.sol    # Base implementation (contributors)
│   │       └── README.md
│   ├── provenance/      # Input/output commitment & integrity
│   │   └── ERC8281/     # OCP + WYRIWE (future)
│   ├── eligibility/     # Permission to act
│   │   └── ReceiptOS/   # (future)
│   ├── interfaces/      # Cross-domain shared interfaces (e.g., IERC165)
│   ├── utils/           # Shared utility contracts
│   └── mocks/           # Mock contracts for testing
├── test/                # Tests mirror contracts/ structure
│   ├── verify/ERC8274/
│   ├── execution/ERC8301/
│   ├── identity/ERC8004/
│   └── ...
├── .github/
├── foundry.toml
├── README.md
└── LICENSE
```

### Conventions

- **Function category → ERC number**: `contracts/<category>/<ERCXXXX>/`
- **One ERC per directory**: interfaces, base implementation, and README live together
- **Test mirror**: `test/` mirrors `contracts/` exactly
- **README per ERC**: each ERC directory contains a README with spec links, discussion threads, interface inventory, and relation to other ERCs
- **Shared code**: cross-ERC interfaces go in `contracts/interfaces/`; utilities in `contracts/utils/`

---

## Code Classification

Every `.sol` file in this repository falls into exactly one of these categories:

| Type | Definition | Production-ready | Where |
|------|-----------|:---:|--------|
| **Interface** | Method signatures, structs, enums defined by the ERC specification | ✅ Must implement | `agent-ercs` |
| **Base Implementation** | Inheritable, audited production contract that implements the interface | ✅ Can inherit for production | `agent-ercs` |
| **Example / Reference** | Demonstrates how to use the interface; not audited | ❌ Do not use in production | Other repositories |

**Base implementations are not examples.** A base implementation is audited (or on a clear path to audit), follows security best practices, and is safe to inherit in production contracts. Examples and reference implementations belong in separate repositories (e.g., `agent-sdk`, project repos).

---

## Current Interfaces

| ERC | Category | Interfaces | Spec | Discussion |
|-----|----------|-----------|------|------------|
| **ERC-8274** | `verify/` | `IProofVerifier`, `IAgentVerifier`, `IAgentVerifiable` | [PR #1771](https://github.com/ethereum/ERCs/pull/1771) | [#28083](https://ethereum-magicians.org/t/erc-8274-ai-inference-proof-verification/28083) |
| **ERC-8301** | `execution/` | `IAgentWorkflow` | PR | [#28785](https://ethereum-magicians.org/t/erc-8301-ai-agent-execution/28785) |
| **ERC-8004** | `identity/` | `IIdentityRegistry`, `IReputationRegistry`, `IValidationRegistry` | PR | [#25098](https://ethereum-magicians.org/t/erc-8004-trustless-agents/25098) |

---

## Setup

### Install Dependencies

```bash
forge install OpenZeppelin/openzeppelin-contracts
```

### Build

```bash
forge build
```

### Test

```bash
forge test
```

---

## Contributing

1. **Add a new ERC**: create `contracts/<category>/<ERCXXXX>/` with at minimum an interface file and a README.md
2. **Add a base implementation**: it must be audited or on a clear audit path; document which audit in the README
3. **Add an example**: examples do NOT go here — put them in the appropriate project repository
4. **Tests**: tests go in `test/<category>/<ERCXXXX>/`, mirroring the contracts structure

### What goes where — quick guide

| You want to... | Put it in |
|---------------|-----------|
| Define the standard interface | `contracts/<category>/<ERCXXXX>/I*.sol` |
| Ship a production-ready inheritable contract | `contracts/<category>/<ERCXXXX>/<Name>.sol` |
| Show developers how to use the interface | Another repo (project repo, `agent-sdk`, etc.) |

---

## License

Apache 2.0 — see [LICENSE](./LICENSE).
