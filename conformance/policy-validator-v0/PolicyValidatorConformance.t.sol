// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IPolicyValidator} from "../../contracts/policy/IPolicyValidator.sol";
import {IPolicyRule} from "../../contracts/policy/IPolicyRule.sol";

/// @notice A minimal policy rule that always passes.
contract AlwaysPassRule is IPolicyRule {
    function check(uint256, bytes calldata, uint256)
        external
        pure
        returns (bool allowed, string memory reason)
    {
        return (true, "");
    }
}

/// @notice A policy rule that always blocks.
contract AlwaysBlockRule is IPolicyRule {
    function check(uint256, bytes calldata, uint256)
        external
        pure
        returns (bool allowed, string memory reason)
    {
        return (false, "blocked by test rule");
    }
}

/// @notice Minimal PolicyValidator composing two IPolicyRule instances.
contract MinimalPolicyValidator is IPolicyValidator {
    IPolicyRule[] private _rules;

    constructor(address[] memory rules) {
        for (uint256 i = 0; i < rules.length; i++) {
            _rules.push(IPolicyRule(rules[i]));
        }
    }

    function evaluate(
        uint256 agentId,
        bytes calldata action,
        string calldata intent,
        uint256 chainId
    ) external returns (Decision decision, string memory reason, bytes memory evidence) {
        for (uint256 i = 0; i < _rules.length; i++) {
            (bool allowed, string memory ruleReason) = _rules[i].check(agentId, action, chainId);
            if (!allowed) {
                decision = Decision.Block;
                reason = ruleReason;
                evidence = abi.encode(ruleReason);
                emit PolicyEvaluated(agentId, uint8(decision), reason, keccak256(evidence));
                return (decision, reason, evidence);
            }
        }
        decision = Decision.Pass;
        reason = "all rules passed";
        evidence = "";
        emit PolicyEvaluated(agentId, uint8(decision), reason, bytes32(0));
        return (decision, reason, evidence);
    }
}

/// @notice Conformance tests for ERC-8xxx Agent Policy Enforcement.
contract PolicyValidatorConformanceTest is Test {
    MinimalPolicyValidator validator;
    AlwaysPassRule passRule;
    AlwaysBlockRule blockRule;

    function setUp() public {
        passRule = new AlwaysPassRule();
        blockRule = new AlwaysBlockRule();
    }

    function test_Pass_WhenAllRulesPass() public {
        address[] memory rules = new address[](1);
        rules[0] = address(passRule);
        validator = new MinimalPolicyValidator(rules);

        (IPolicyValidator.Decision decision, string memory reason,) =
            validator.evaluate(1, hex"", "test intent", 1);

        assertEq(uint256(decision), uint256(IPolicyValidator.Decision.Pass));
        assertEq(reason, "all rules passed");
    }

    function test_Block_WhenAnyRuleBlocks() public {
        address[] memory rules = new address[](2);
        rules[0] = address(passRule);
        rules[1] = address(blockRule);
        validator = new MinimalPolicyValidator(rules);

        (IPolicyValidator.Decision decision, string memory reason,) =
            validator.evaluate(1, hex"", "test intent", 1);

        assertEq(uint256(decision), uint256(IPolicyValidator.Decision.Block));
        assertEq(reason, "blocked by test rule");
    }

    function test_Block_FirstRuleBlocks() public {
        address[] memory rules = new address[](2);
        rules[0] = address(blockRule);
        rules[1] = address(passRule);
        validator = new MinimalPolicyValidator(rules);

        (IPolicyValidator.Decision decision, string memory reason,) =
            validator.evaluate(2, hex"deadbeef", "multi-rule test", 8453);

        assertEq(uint256(decision), uint256(IPolicyValidator.Decision.Block));
        assertEq(reason, "blocked by test rule");
    }

    function test_EmitsPolicyEvaluated() public {
        address[] memory rules = new address[](1);
        rules[0] = address(blockRule);
        validator = new MinimalPolicyValidator(rules);

        vm.expectEmit(true, true, true, true);
        emit IPolicyValidator.PolicyEvaluated(
            1, uint8(IPolicyValidator.Decision.Block), "blocked by test rule", bytes32(0)
        );

        validator.evaluate(1, hex"", "test intent", 1);
    }
}
