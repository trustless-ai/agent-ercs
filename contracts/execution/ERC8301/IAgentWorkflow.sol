// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IAgentWorkflow — Universal AI Agent Execution Interface
/// @notice On-chain execution primitive for AI agent task dispatch, orchestration,
///         and verifiable step execution.
/// @dev    Part of ERC-8301 (AI Agent Execution).
///         The workflow contract is a finite state machine (FSM) that drives all
///         stage transitions. Agents react to emitted tasks; they do not control sequencing.

// ── Enums ────────────────────────────────────────────────────────────────────

/// @notice Terminal status of a workflow run.
enum RunStatus {
    Pending, // Run is active; no result yet
    Success, // FSM reached a terminal stage with all gates satisfied
    Failed   // Run aborted
}

// ── Data Structures ──────────────────────────────────────────────────────────

/// @notice Task dispatched by the workflow contract to agents.
/// @dev    taskHash = keccak256(abi.encode(
///             task.stage, task.taskSeq, task.inputHash, task.timestamp,
///             task.expiresAt, keccak256(abi.encodePacked(task.prevReplyHashes)),
///             task.workflowRunId))
///         When prevReplyHashes is empty, the inner term MUST be
///         keccak256(abi.encodePacked([])) = keccak256("") =
///         0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470.
struct AgentTask {
    uint8     stage;            // FSM stage (developer-defined enum cast to uint8)
    uint256   taskSeq;          // Per-run monotonic counter; starts at 0
    bytes32   inputHash;        // keccak256(input)
    bytes     input;            // Input plaintext; MAY be empty if conveyed off-chain
    uint256   timestamp;        // block.timestamp at emission
    uint256   expiresAt;        // Unix timestamp after which this task is no longer valid
    bytes32[] prevReplyHashes;  // Replies that triggered this task; empty for the initial task
    bytes32   workflowRunId;    // Run identifier
}

/// @notice Reply submitted by an agent in response to a dispatched task.
/// @dev    replyHash = keccak256(abi.encode(
///             reply.outputHash, reply.timestamp, reply.replier,
///             keccak256(abi.encodePacked(reply.prevTaskHashes)),
///             reply.workflowRunId))
struct AgentReply {
    bytes32   outputHash;       // keccak256(output)
    bytes     output;           // Reply output plaintext; MAY be empty
    uint256   timestamp;        // Off-chain execution time (Unix)
    address   replier;          // Agent address; MUST equal msg.sender when submitted
    bytes32[] prevTaskHashes;   // Tasks this reply responds to; MUST be non-empty
    bytes32   workflowRunId;    // Run identifier
}

// ── Core Interface ───────────────────────────────────────────────────────────

interface IAgentWorkflow {
    // ── Invocation ───────────────────────────────────────────────────────────

    /// @notice Start a new workflow run.
    /// @param  inputHash     keccak256 of the input
    /// @param  input         Input plaintext; MAY be empty if conveyed off-chain
    /// @param  expiresAt     Unix timestamp after which the initial task expires
    /// @return workflowRunId Contract-generated unique run identifier
    function run(
        bytes32        inputHash,
        bytes calldata input,
        uint256        expiresAt
    ) external returns (bytes32 workflowRunId);

    /// @notice Query the result of a run.
    /// @return status        Pending | Success | Failed
    /// @return finalTaskHash taskHash of the terminal AgentTask; bytes32(0) if not Success
    /// @return completedAt   block.timestamp at completion; 0 if not Success
    function result(bytes32 workflowRunId)
        external view
        returns (RunStatus status, bytes32 finalTaskHash, uint256 completedAt);

    // ── Query ────────────────────────────────────────────────────────────────

    /// @notice Returns the stored AgentTask and its proven status.
    /// @dev    MUST revert if taskHash is unknown.
    ///         proven=true iff prevReplyHashes is empty OR all prevReplyHashes are proven.
    function getAgentTask(bytes32 taskHash)
        external view
        returns (AgentTask memory task, bool proven);

    /// @notice Returns the stored AgentReply and its verification status.
    /// @dev    MUST revert if replyHash is unknown.
    function getAgentReply(bytes32 replyHash)
        external view
        returns (
            AgentReply memory reply,
            address           verifier,
            bool              proven,
            bytes32           verificationDigest
        );

    // ── Agent Callbacks ──────────────────────────────────────────────────────

    /// @notice Agent submits a reply to a dispatched task.
    /// @param  reply  See AgentReply; reply.replier MUST equal msg.sender
    function onAgentReply(AgentReply calldata reply) external;

    /// @notice Submit a cryptographic proof covering one or more anchored replies.
    /// @param  replyHashes Each MUST have been anchored by onAgentReply
    /// @param  proof       Proof bytes covering all listed replies; encoding is
    ///                     verifier-specific
    function onAgentProve(
        bytes32[] calldata replyHashes,
        bytes calldata proof
    ) external;

    // ── Events ───────────────────────────────────────────────────────────────

    /// @notice Emitted when a new task is dispatched.
    ///         Full details via getAgentTask(taskHash).
    event NewAgentTask(
        bytes32 indexed workflowRunId,
        uint8   indexed stage,
        bytes32 indexed taskHash
    );

    /// @notice Emitted when a run reaches a terminal state.
    event WorkflowCompleted(
        bytes32   indexed workflowRunId,
        RunStatus         status,
        bytes32           finalTaskHash,
        uint256           timestamp
    );
}
