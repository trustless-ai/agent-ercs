# ERC-8301: AI Agent Execution

- **Spec**: [ERC-8301](https://github.com/ethereum/ERCs/pull/...)
- **Discussion**: [Ethereum Magicians #28785](https://ethereum-magicians.org/t/erc-8301-ai-agent-execution/28785)
- **Status**: Draft
- **Author**: JimmyShi22

## Interfaces

| File | Role |
|------|------|
| `IAgentWorkflow.sol` | Universal agent execution interface + `AgentTask` / `AgentReply` / `RunStatus` |
| `IConfidentialStep.sol` | A stage gated by an ERC-8354 verdict instead of plaintext output |

## Architecture

`IAgentWorkflow` is a **finite state machine (FSM)** driven entirely by the contract:

```
run(inputHash, input, expiresAt)
    → emits NewAgentTask(stage=initial)
    → Agent observes → calls onAgentReply(...)
    → Contract validates gate logic → emits next NewAgentTask (or WorkflowCompleted)
    → ... repeat until terminal stage
```

### Evidence Chain

Every `AgentTask` and `AgentReply` is linked via bidirectional hashes:

- `AgentTask.prevReplyHashes` → which replies triggered this task
- `AgentReply.prevTaskHashes` → which tasks this reply responds to

Any party can traverse from `result().finalTaskHash` back to `run()` and verify every transition was gate-approved.

## Confidential steps

A workflow stage whose reply carries no plaintext output. The action and the policy stay hidden; the fact that the action cleared the policy stays verifiable. `IConfidentialStep.sol` defines that path by composing ERC-8301 with [ERC-8354](../../verify/ERC8354/README.md).

It changes neither standard and introduces no new commitment scheme. There is no new function on `IAgentWorkflow`, and no second action-commitment formula: `PolicyActionLib.commit` is normative, so a confidential step MAPS INTO the canonical `PolicyAction` fields rather than defining its own hash. A domain that can issue verdicts today can gate a workflow today.

The confidential path rides the existing `onAgentProve(replyHashes, proof)` seam, whose proof encoding the spec already leaves verifier-specific, and fixes that encoding to `abi.encode(Verdict, proof, actionNonce)`.

| `PolicyAction` field | what a confidential step puts there |
|---|---|
| `chainId` | `block.chainid` |
| `domainId` | the workflow's `policyDomain()` |
| `agentId` | the ERC-8004 identity of the agent that replied |
| `target` | the workflow contract |
| `value` | `0`, a step moves no value |
| `callDataHash` | a domain-separated commitment to `(workflowRunId, replyHash)` |
| `actionNonce` | monotonic per `(domain, agent)` |

Three bindings fall out of that mapping, and the interface requires a fourth check the mapping cannot carry.

| Binding | Where it lives | Without it |
|---|---|---|
| the exact step | `callDataHash` | a verdict for one action gates an unrelated reply |
| the replying agent | `agentId` | one agent's verdict gates another agent's reply |
| the chain and domain | `chainId`, `domainId` | cross-chain or cross-domain replay |
| the domain the workflow trusts | `policyDomain()` check | an ALLOW from a more permissive domain gates a stricter step |

That last one is not implied by the commitment. The ERC-8354 Guard validates whichever domain the verdict supplies; it has no way to know which domain this workflow intended to trust. `PolicyDomainMismatch` makes the boundary explicit.

The executor is the **workflow contract**, not the replier. Direct `consume` requires `v.executor == msg.sender`, and on this path the caller is the workflow reached through `onAgentProve`; naming the replier would make the direct path unsatisfiable and force the relayed overload, which needs an `executorAuth` signature the workflow cannot obtain mid-transition. Nothing is lost, because the agent binding is carried by `agentId` inside the normative commitment. `executor` answers a different question, which is who may submit, and in a workflow the submitter is the workflow. Consumption stays atomic with the transition rather than being a separable call another party can front-run.

### Refusals stay distinguishable

A step gated shut carries `policyKind`, not just a failed gate. "A rule refused this", "nothing authorized this", and "the policy could not be evaluated" reach the consumer as different states. For a step that must prove it was refused rather than never attempted, the refusal is anchored separately; that companion lives in the CAPV repository, since this repository holds interfaces rather than reference implementations.

This is the confidential half of the gap that `AgentReplyAnchored` closes on the transparent side: a reply that was anchored but never gated is observable as exactly that, via `stepVerdict(replyHash).settled == false`.

> Note: `IAgentWorkflow.sol` here does not yet carry the `AgentReplyAnchored` event agreed on the discussion thread. Worth syncing separately from this file.

## Related ERCs

- [ERC-8274](https://github.com/ethereum/ERCs/pull/1771) — AI Inference Proof Verification (verifies agent replies)
- [ERC-8354](../../verify/ERC8354/README.md) — Confidential Agent Policy Verdicts (gates a confidential step)
- [ERC-8004](https://github.com/ethereum/ERCs/pull/...) — Trustless Agents (agent identity)
- [ERC-8281 / OCP](https://github.com/ethereum/ERCs/pull/...) — input provenance
