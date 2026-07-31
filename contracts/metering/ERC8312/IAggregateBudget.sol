// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title IAggregateBudget — Aggregate Budget Profile of ERC-8312
/// @notice Optional companion profile of Bounded Agent Actions. The base
///         profile (`IBoundedAgentAction` / `IBudgetSubstrate`) meters ONE
///         envelope's cumulative spend. This profile meters the aggregate spend
///         of a whole DELEGATION TREE against a single root cap: an agent may
///         spawn sub-agents, which re-delegate further, each acting under its
///         own key, and the sum of spend across every node in a period is
///         bounded by one conserved root budget.
///
///         A delegation tree is not an envelope, so this interface does NOT
///         extend `IBoundedAgentAction`; an implementation MAY support both
///         interface ids. The base interfaces are unchanged.
///
/// @dev    NORMATIVE CONSERVATION PROPERTY (spec Section 5, ethereum/ERCs
///         PR 1833). For every root and every period,
///
///             sum over all admitted draw() of amount  <=  root cap.
///
///         This holds regardless of fan-out, depth, or re-delegation. Two
///         conformance facts make it non-trivial:
///
///         - Edge-keyed accounting is non-conformant. A fresh spend counter per
///           delegation edge (the shape of per-grant allowances, caveat chains,
///           session keys, ERC-7710 redelegation) admits an UNBOUNDED
///           aggregate: a root can open k sibling paths each capped at B and
///           realize k*B while every per-edge check passes.
///
///         - The meter must be root-keyed and admin-free. A finite aggregate
///           bound exists only where the running accumulator is a single
///           register keyed on the ROOT (not the edge) with no owner, upgrade,
///           or administrative authority able to reset, decrement, or replace
///           it. A meter behind such an authority is conserved only until the
///           authority is exercised.
///
///         SCOPE, stated honestly and normatively:
///         - SAFETY, SINGLE CHAIN. The bound is enforced by the serialized
///           check-then-increment of one register. Cross-chain aggregation of
///           one live cap is out of scope.
///         - NO PER-SUBTREE METER. The only conserved quantity is the global
///           root. An optional per-node attenuation cap MAY bound a single
///           node's own draws, but it does NOT ring-fence a sub-budget for that
///           node's subtree; implementations MUST NOT present a node cap as a
///           subtree cap.
///         - NON-BYPASSABILITY is a substrate obligation. The meter holds the
///           sum of the draws routed through it; this interface meters and does
///           not itself move assets or gate execution.
///         - NO RESERVE/REFUND. Draws are final within a period; revocation
///           MUST NOT decrement the root meter (realized spend stays realized),
///           so revocation only shrinks future headroom, never mints it.
interface IAggregateBudget is IERC165 {
    /// @notice Emitted when a delegation tree is created. `agent` is node 0.
    event RootCreated(
        bytes32 indexed rootId, address indexed issuer, address indexed agent, uint256 cap, uint64 periodLength
    );

    /// @notice Emitted when a child node is delegated beneath `parentId`.
    event NodeDelegated(
        bytes32 indexed rootId, uint64 indexed parentId, uint64 indexed nodeId, address agent, uint256 nodeCap
    );

    /// @notice Emitted on every admitted draw against the conserved root meter.
    event Drawn(bytes32 indexed rootId, uint64 indexed nodeId, uint64 indexed periodIndex, uint256 amount);

    /// @notice Emitted when a node (and, transitively, its subtree) is revoked.
    event NodeRevoked(bytes32 indexed rootId, uint64 indexed nodeId);

    // --------------------------------------------------------------------- //
    // Tree construction                                                     //
    // --------------------------------------------------------------------- //

    /// @notice Create a delegation tree with a conserved budget `cap` per period,
    ///         rooted at `agent` (node 0). The caller is the issuer/principal.
    /// @param agent        The key that may draw through / delegate under node 0.
    /// @param cap          The conserved budget per period, shared by the tree.
    /// @param periodLength Seconds per period; 0 for a single non-resetting period.
    /// @param periodAnchor Start of period 0 when `periodLength != 0`.
    /// @param salt         Disambiguates otherwise-identical trees by the same issuer.
    /// @return rootId      Deterministic tree identifier.
    function createRoot(address agent, uint256 cap, uint64 periodLength, uint64 periodAnchor, bytes32 salt)
        external
        returns (bytes32 rootId);

    /// @notice Delegate a child node under `parentId`. Only the parent node's
    ///         agent may extend the tree, and only while its path to the root is
    ///         unrevoked. The child shares the root meter; it never receives a
    ///         fresh budget. `nodeCap` (0 = none) attenuates the child's OWN draws.
    /// @return nodeId The new node's identifier.
    function delegate(bytes32 rootId, uint64 parentId, address agent, uint256 nodeCap)
        external
        returns (uint64 nodeId);

    /// @notice Meter a spend of `amount` by `nodeId`. MUST revert unless the caller
    ///         is the node's agent, every node on the path to the root is
    ///         unrevoked, the node's own attenuation cap (if any) is respected, and
    ///         — conservation — the single root meter stays within the root cap.
    function draw(bytes32 rootId, uint64 nodeId, uint256 amount) external;

    /// @notice Revoke a node and, transitively, every draw path through its
    ///         subtree. Authorized for the tree's issuer or the node's parent agent.
    ///         MUST NOT decrement the root meter.
    function revoke(bytes32 rootId, uint64 nodeId) external;

    // --------------------------------------------------------------------- //
    // Views (stranger-recomputable; the conservation property is auditable) //
    // --------------------------------------------------------------------- //

    /// @return issuer       The principal who created the tree.
    /// @return cap          The conserved per-period budget.
    /// @return periodLength Seconds per period (0 = single period).
    /// @return periodAnchor Start of period 0.
    /// @return nodeCount    Next node id (== number of nodes).
    function rootOf(bytes32 rootId)
        external
        view
        returns (address issuer, uint256 cap, uint64 periodLength, uint64 periodAnchor, uint64 nodeCount);

    /// @return parent  Parent node id (node 0 is its own parent sentinel).
    /// @return depth   Depth from the root (node 0 has depth 0).
    /// @return revoked Whether this node has been revoked.
    /// @return agent   The key that may draw through / delegate under this node.
    /// @return nodeCap The node's own per-period attenuation cap (0 = none).
    function nodeOf(bytes32 rootId, uint64 nodeId)
        external
        view
        returns (uint64 parent, uint8 depth, bool revoked, address agent, uint256 nodeCap);

    /// @notice Realized aggregate spend of the whole tree in `periodIndex`. This is
    ///         THE conserved meter; the normative property is `<= cap`.
    function spentRoot(bytes32 rootId, uint64 periodIndex) external view returns (uint256);

    /// @notice Remaining conserved headroom of the whole tree in the current period.
    function remainingRoot(bytes32 rootId) external view returns (uint256);

    /// @notice Current period index of the tree (0 when periodLength == 0).
    function currentPeriod(bytes32 rootId) external view returns (uint64);

    /// @notice True iff every node from `nodeId` up to the root is unrevoked.
    function isPathActive(bytes32 rootId, uint64 nodeId) external view returns (bool);
}
