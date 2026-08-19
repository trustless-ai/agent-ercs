# ERC-8274: AI Inference Proof Verification Interfaces

- **Spec**: [ERC-8274](https://github.com/ethereum/ERCs/pull/1771)
- **Discussion**: [Ethereum Magicians #28083](https://ethereum-magicians.org/t/erc-8274-ai-inference-proof-verification/28083)
- **Status**: Draft
- **Authors**: JimmyShi22, Damonzwicker, TMerlini, babyblueviper1

## Interfaces

| File | Layer | Role |
|------|-------|------|
| `IProofVerifier.sol` | Inner (stateless) | Cryptographic proof verification — "is this proof valid?" |
| `IAgentVerifier.sol` | Outer (stateful) | Agent authorization + proof routing — "is this agent authorized and was the proof verified?" |
| `IAgentVerifiable.sol` | Declaration | Declares which `IAgentVerifier` a settlement contract trusts |

## Architecture

```
Settlement Contract (IAgentVerifiable)
    └── IAgentVerifier
            └── IProofVerifier (zkML / opML / TEE / ...)
```

- `IAgentVerifiable` → settlement contracts declare their verifier
- `IAgentVerifier` → wraps proof verifier(s) with agent identity checks
- `IProofVerifier` → stateless, proof-system-agnostic cryptographic verification

## Related ERCs

- [ERC-8281 / OCP](https://github.com/ethereum/ERCs/pull/1788) — input provenance (what was committed)
- [ERC-8263 / TruthAnchor](https://github.com/ethereum/ERCs/pull/...) — temporal anchoring (when it was committed)
- [ERC-8301](https://github.com/ethereum/ERCs/pull/1815) — execution dispatch (the task that produced the inference)
