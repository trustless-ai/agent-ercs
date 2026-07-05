# ERC-8301: AI Agent Execution

- **Spec**: [ERC-8301](https://github.com/ethereum/ERCs/pull/...)
- **Discussion**: [Ethereum Magicians #28785](https://ethereum-magicians.org/t/erc-8301-ai-agent-execution/28785)
- **Status**: Draft
- **Author**: JimmyShi22

## Interfaces

| File | Role |
|------|------|
| `IAgentWorkflow.sol` | Universal agent execution interface + `AgentTask` / `AgentReply` / `RunStatus` |

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

## Related ERCs

- [ERC-8274](https://github.com/ethereum/ERCs/pull/1771) — AI Inference Proof Verification (verifies agent replies)
- [ERC-8004](https://github.com/ethereum/ERCs/pull/...) — Trustless Agents (agent identity)
- [ERC-8281 / OCP](https://github.com/ethereum/ERCs/pull/...) — input provenance
