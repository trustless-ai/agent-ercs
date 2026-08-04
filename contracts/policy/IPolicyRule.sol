// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IPolicyRule — Composable Policy Rule
/// @notice Individual policy rule that can be composed into a PolicyValidator.
///         Each rule answers one question: is this action allowed?
/// @dev    Rules are composable: a PolicyValidator evaluates an ordered list
///         of rules and returns the first non-Pass decision.
interface IPolicyRule {
    /// @notice Check whether this rule permits the action.
    /// @param agentId The ERC-8004 agent identifier.
    /// @param action  Encoded action payload.
    /// @param chainId The execution chain ID.
    /// @return allowed True if the action passes this rule.
    /// @return reason  Explanation if not allowed.
    function check(
        uint256 agentId,
        bytes calldata action,
        uint256 chainId
    )
        external
        view
        returns (bool allowed, string memory reason);
}
