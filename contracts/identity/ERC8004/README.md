# ERC-8004: Trustless Agents

- **Spec**: [ERC-8004](https://github.com/ethereum/ERCs/pull/1170)
- **Discussion**: [Ethereum Magicians #25098](https://ethereum-magicians.org/t/erc-8004-trustless-agents/25098)
- **Status**: Draft
- **Authors**: Marco De Rossi (@MarcoMetaMask), Davide Crapis (@dcrapis), Jordan Ellis, Erik Reppel

## Interfaces

| File | Role |
|------|------|
| `IIdentityRegistry.sol` | Agent identity via ERC-721 + metadata + wallet management |
| `IReputationRegistry.sol` | Feedback signals: give, revoke, append responses, query |
| `IValidationRegistry.sol` | Validation request/response between agents and validators |

## Architecture

```
IIdentityRegistry (ERC-721 extended)
    ├── register / setAgentURI  → agent registration file
    ├── setAgentWallet           → EIP-712/ERC-1271 proof of wallet control
    └── setMetadata / getMetadata → on-chain agent metadata

IReputationRegistry
    ├── giveFeedback / revokeFeedback → client feedback signals
    ├── appendResponse                 → agent or third-party responses
    └── getSummary / readAllFeedback    → on-chain composable reputation

IValidationRegistry
    ├── validationRequest  → agent requests validation
    ├── validationResponse → validator responds (0-100 scale)
    └── getSummary         → aggregated validation statistics
```

## Related ERCs

- [ERC-8274](https://github.com/ethereum/ERCs/pull/1771) — AI Inference Proof Verification (validators can implement `IProofVerifier`)
- [ERC-8301](https://github.com/ethereum/ERCs/pull/1815) — AI Agent Execution (agents registered here execute tasks there)
