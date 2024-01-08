// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBDirectory} from "lib/juice-contracts-v4/src/interfaces/IJBDirectory.sol";
import {IJBProjects} from "lib/juice-contracts-v4/src/interfaces/IJBProjects.sol";
import {IJBController} from "lib/juice-contracts-v4/src/interfaces/IJBController.sol";

import {JBDeploy721TiersHookConfig} from "../structs/JBDeploy721TiersHookConfig.sol";
import {JBLaunchProjectConfig} from "../structs/JBLaunchProjectConfig.sol";
import {JBLaunchRulesetsConfig} from "../structs/JBLaunchRulesetsConfig.sol";
import {JBQueueRulesetsConfig} from "../structs/JBQueueRulesetsConfig.sol";
import {IJB721TiersHookDeployer} from "./IJB721TiersHookDeployer.sol";

interface IJB721TiersHookProjectDeployer {
    function DIRECTORY() external view returns (IJBDirectory);

    function HOOK_DEPLOYER() external view returns (IJB721TiersHookDeployer);

    function launchProjectFor(
        address owner,
        JBDeploy721TiersHookConfig memory deployTiersHookConfig,
        JBLaunchProjectConfig memory launchProjectConfig,
        IJBController controller
    )
        external
        returns (uint256 projectId);

    function launchRulesetsFor(
        uint256 projectId,
        JBDeploy721TiersHookConfig memory deployTiersHookConfig,
        JBLaunchRulesetsConfig memory launchRulesetsConfig,
        IJBController controller
    )
        external
        returns (uint256 rulesetId);

    function queueRulesetsOf(
        uint256 projectId,
        JBDeploy721TiersHookConfig memory deployTiersHookConfig,
        JBQueueRulesetsConfig memory queueRulesetsConfig,
        IJBController controller
    )
        external
        returns (uint256 rulesetId);
}
