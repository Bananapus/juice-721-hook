// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/juice-contracts-v4/src/structs/JBRulesetConfig.sol";
import "lib/juice-contracts-v4/src/structs/JBTerminalConfig.sol";

/// @custom:member projectId The ID of the project to launch rulesets for.
/// @custom:member rulesetConfigurations The ruleset configurations to queue.
/// @custom:member terminalConfigurations The terminal configurations to add for the project.
/// @custom:member memo A memo to pass along to the emitted event.
struct JBLaunchRulesetsConfig {
    uint256 projectId;
    JBRulesetConfig[] rulesetConfigurations;
    JBTerminalConfig[] terminalConfigurations;
    string memo;
}
