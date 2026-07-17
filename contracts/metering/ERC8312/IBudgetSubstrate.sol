// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IBoundedAgentAction} from "./IBoundedAgentAction.sol";

/// @title IBudgetSubstrate — ERC-8312 Budget Substrate Profile
/// @notice Typed read surface for the budget profile: one cap, one asset, one
///         cumulative spent value per envelope, so a consumer reads remaining
///         headroom directly instead of interpreting the opaque cursor.
/// @dev    Under this profile capabilityRoot = keccak256(abi.encode(cap, asset))
///         and cursorRoot = keccak256(abi.encode(spent)). A conforming registry
///         MUST maintain spent <= cap while Active, spent monotonically
///         non-decreasing, and keccak256(abi.encode(cap - remaining(id))) equal
///         to getCursor(id) while Active, so the typed accessor and the
///         commitment cannot diverge. ERC-165 interfaceId: 0x021ca455 (frozen).
interface IBudgetSubstrate is IBoundedAgentAction {
    /// @notice Configured bound: maximum cap of asset consumable under the
    ///         envelope. MUST revert on an unknown id.
    function bound(bytes32 id) external view returns (uint256 cap, address asset);

    /// @notice Cumulative value consumed under the envelope. MUST revert on an
    ///         unknown id.
    function spent(bytes32 id) external view returns (uint256);

    /// @notice Remaining headroom (cap - spent), or 0 if the envelope is not
    ///         active. Zero does not self-disambiguate between an exhausted
    ///         bound and an inactive envelope; consult isActive.
    function remaining(bytes32 id) external view returns (uint256);
}
