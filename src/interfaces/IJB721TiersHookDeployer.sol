// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBDirectory} from "lib/juice-contracts-v4/src/interfaces/IJBDirectory.sol";

import {JB721GovernanceType} from "../enums/JB721GovernanceType.sol";
import {JBDeploy721TiersHookConfig} from "../structs/JBDeploy721TiersHookConfig.sol";
import {IJB721TiersHook} from "./IJB721TiersHook.sol";

interface IJB721TiersHookDeployer {
    event HookDeployed(uint256 indexed projectId, IJB721TiersHook newHook, JB721GovernanceType governanceType);

    function deployHookFor(
        uint256 projectId,
        JBDeploy721TiersHookConfig memory deployTiersHookConfig
    )
        external
        returns (IJB721TiersHook hook);
}
