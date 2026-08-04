# ERC-8xxx: Agent Policy Enforcement

> **Category:** `policy/` — Programmable trust rules between identity verification and execution.

## Specification

An agent that has passed identity checks (ERC-8004) and been dispatched a task (ERC-8301) MAY still be blocked by a policy validator before the action reaches settlement. This ERC defines the interface for that programmable trust layer.

## Position in the boundary chain

```
identity (ERC-8004) → [POLICY (this ERC)] → dispatch (ERC-8301) → provenance → verify → anchor
```

## Interfaces

| Interface | File | Purpose |
|-----------|------|---------|
| `IPolicyValidator` | `IPolicyValidator.sol` | Evaluates an agent action and returns Pass/Block/PendingHITL |
| `IPolicyRule` | `IPolicyRule.sol` | Individual composable policy rule |

## Decision Model

| Value | Name | Meaning |
|-------|------|---------|
| 0 | Pass | Action is permitted; proceed to execution |
| 1 | Block | Action is denied; do not execute |
| 2 | PendingHITL | Action is suspended; human approval required before execution |

The `PendingHITL` state is unique among ERC decision models — it introduces a pause-for-human primitive that existing ERCs (8004, 8301, 8275) do not cover.

## Composable Rules

A `IPolicyValidator` implementation evaluates an ordered list of `IPolicyRule` instances. The first non-Pass rule short-circuits evaluation and returns its decision. Rule types supported by the reference implementation:

| Rule | Checks |
|------|--------|
| AmountLimit | Value does not exceed per-transaction cap |
| Destination | Recipient is in the allowed set |
| Frequency | Action rate is within time-window limits |
| HITL | Value exceeds threshold → requires human approval |
| Reputation | Agent reputation score meets minimum |
| TxTypeAllowlist | Action type is in the permitted set |
| StakeWeighted | Limits scale with staked collateral |
| Geofence | Execution chain is in the approved set |
| SpeedLimit | Action frequency is within burst limits |
| EnergyBudget | Gas/Compute budget is within allocation |
| OperatingHours | Action is within permitted time windows |

## Reference Implementation

The reference implementation lives in the [Bastion](https://github.com/zkos-labs/bastion) repository:

- **Solidity:** `evm/src/BastionPolicy.sol` — On-chain policy rules with per-agent allowlists, limits, and cooldowns.
- **Rust:** `crates/core/src/policy/evaluator.rs` — Chain-agnostic `PolicyEvaluator<P: TrustSignalProvider>` with 11 rule types, trust signal consumption, and simulation gating.

## Discussion

- [Ethereum Magicians](https://ethereum-magicians.org/) — proposal link TBD
- [Bastion Policy Engine](https://github.com/zkos-labs/bastion) — reference implementation
