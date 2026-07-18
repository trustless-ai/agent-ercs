// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IBoundedAgentAction} from "../../../contracts/metering/ERC8312/IBoundedAgentAction.sol";
import {IBudgetSubstrate} from "../../../contracts/metering/ERC8312/IBudgetSubstrate.sol";
import {IContestableEnvelope} from "../../../contracts/metering/ERC8312/IContestableEnvelope.sol";

/// @notice Pins the frozen ERC-8312 ERC-165 identifiers. If any function
///         signature drifts from the spec, these fail before an integrator
///         discovers the mismatch on-chain.
contract InterfaceIdsTest is Test {
    function test_boundedAgentAction_interfaceId_frozen() public pure {
        assertEq(type(IBoundedAgentAction).interfaceId, bytes4(0x3985961d));
    }

    function test_budgetSubstrate_interfaceId_frozen() public pure {
        assertEq(type(IBudgetSubstrate).interfaceId, bytes4(0x021ca455));
    }

    function test_contestableEnvelope_interfaceId_frozen() public pure {
        assertEq(type(IContestableEnvelope).interfaceId, bytes4(0xe664d441));
    }
}
