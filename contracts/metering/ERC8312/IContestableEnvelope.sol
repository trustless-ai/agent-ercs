// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IBoundedAgentAction} from "./IBoundedAgentAction.sol";

/// @title IContestableEnvelope — ERC-8312 Contestation Extension
/// @notice Optional extension providing the Contested state and its
///         transitions. A base registry preserves the Contested enum value for
///         vocabulary uniformity without supporting entry into it; a registry
///         that supports contestation implements this interface.
/// @dev    Discoverable via ERC-165. Where a settlement standard defines its
///         own dispute resolution, Contested is an integration-specific lane
///         and does not replace that arbitration. ERC-165 interfaceId:
///         0xe664d441 (frozen).
interface IContestableEnvelope is IBoundedAgentAction {
    /// @notice Emitted when an envelope enters Contested.
    event EnvelopeContested(bytes32 indexed id, address indexed challenger);

    /// @notice Emitted when a contested envelope is resolved.
    event EnvelopeResolved(bytes32 indexed id, Status outcome);

    /// @notice Active -> Contested. Authorization is implementation-defined,
    ///         for example a bonded challenger. MUST revert unless status is
    ///         Active.
    function contest(bytes32 id, bytes calldata evidence) external;

    /// @notice Contested -> Active or Revoked. MUST be restricted to a
    ///         documented resolver. MUST revert unless status is Contested and
    ///         outcome is Active or Revoked.
    function resolve(bytes32 id, Status outcome, bytes calldata resolution) external;
}
