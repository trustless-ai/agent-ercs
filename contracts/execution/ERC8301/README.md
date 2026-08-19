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

It changes neither standard. There is no new function on `IAgentWorkflow` and no new public input on the ERC-8354 proving program. The confidential path rides the existing `onAgentProve(replyHashes, proof)` seam, whose proof encoding the spec already leaves verifier-specific, and fixes that encoding to `abi.encode(Verdict, proof)`.

What it adds is two bindings.

| Binding | Without it |
|---|---|
| `v.actionCommitment == actionCommitmentFor(workflowRunId, replyHash)` | a verdict issued for one action could gate an unrelated reply |
| `v.executor == reply.replier` | one agent's verdict could gate another agent's reply |

Both use fields that are already part of every `Verdict`, so a domain issuing verdicts today can gate a workflow today.

The commitment is scoped to the run as well as the reply. `replyHash` already covers `workflowRunId`, but a verifier reading only `actionCommitment` should not have to depend on that, and the tests pin it.

### Refusals stay distinguishable

A step gated shut carries `policyKind`, not just a failed gate. "A rule refused this", "nothing authorized this", and "the policy could not be evaluated" reach the consumer as different states. For a step that must prove it was refused rather than never attempted, the refusal is anchored separately; that companion lives in the CAPV repository, since this repository holds interfaces rather than reference implementations.

This is the confidential half of the gap that `AgentReplyAnchored` closes on the transparent side: a reply that was anchored but never gated is observable as exactly that, via `stepVerdict(replyHash).settled == false`.

> Note: `IAgentWorkflow.sol` here does not yet carry the `AgentReplyAnchored` event agreed on the discussion thread. Worth syncing separately from this file.

## Related ERCs

- [ERC-8274](https://github.com/ethereum/ERCs/pull/1771) — AI Inference Proof Verification (verifies agent replies)
- [ERC-8354](../../verify/ERC8354/README.md) — Confidential Agent Policy Verdicts (gates a confidential step)
- [ERC-8004](https://github.com/ethereum/ERCs/pull/...) — Trustless Agents (agent identity)
- [ERC-8281 / OCP](https://github.com/ethereum/ERCs/pull/...) — input provenance
