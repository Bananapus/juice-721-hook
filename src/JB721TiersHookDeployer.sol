// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Clones} from "lib/openzeppelin-contracts/contracts/proxy/Clones.sol";
import {IJBAddressRegistry} from "lib/juice-address-registry/src/interfaces/IJBAddressRegistry.sol";
import {IJBDirectory} from "lib/juice-contracts-v4/src/interfaces/IJBDirectory.sol";
import {JBOwnable} from "lib/juice-ownable/src/JBOwnable.sol";

import {JB721GovernanceType} from "./enums/JB721GovernanceType.sol";
import {IJB721TiersHookDeployer} from "./interfaces/IJB721TiersHookDeployer.sol";
import {IJB721TiersHook} from "./interfaces/IJB721TiersHook.sol";
import {JBDeploy721TiersHookConfig} from "./structs/JBDeploy721TiersHookConfig.sol";
import {JB721TiersHook} from "./JB721TiersHook.sol";
import {JBGoverned721TiersHook} from "./JBGoverned721TiersHook.sol";

/// @title JB721TiersHookDeployer
/// @notice Deploys a `JB721TiersHook`.
contract JB721TiersHookDeployer is IJB721TiersHookDeployer {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error INVALID_GOVERNANCE_TYPE();

    //*********************************************************************//
    // ----------------------- internal properties ----------------------- //
    //*********************************************************************//

    /// @notice This contract's current nonce, used for the Juicebox address registry.
    uint256 internal _nonce;

    //*********************************************************************//
    // --------------- public immutable stored properties ---------------- //
    //*********************************************************************//

    /// @notice A 721 tiers hook that supports on-chain governance across all tiers.
    JBGoverned721TiersHook public immutable ONCHAIN_GOVERNANCE;

    /// @notice A 721 tiers hook without on-chain governance support.
    JB721TiersHook public immutable NO_GOVERNANCE;

    /// @notice A registry which stores references to contracts and their deployers.
    IJBAddressRegistry public immutable ADDRESS_REGISTRY;

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param onchainGovernance Reference copy of the hook which supports on-chain governance.
    /// @param noGovernance Reference copy of a hook without on-chain governance support.
    /// @param addressRegistry A registry which stores references to contracts and their deployers.
    constructor(
        JBGoverned721TiersHook onchainGovernance,
        JB721TiersHook noGovernance,
        IJBAddressRegistry addressRegistry
    ) {
        ONCHAIN_GOVERNANCE = onchainGovernance;
        NO_GOVERNANCE = noGovernance;
        ADDRESS_REGISTRY = addressRegistry;
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Deploys a 721 tiers hook for the specified project.
    /// @param projectId The ID of the project to deploy the hook for.
    /// @param deployTiersHookConfig The config to deploy the hook with, which determines its behavior.
    /// @return newHook The address of the newly deployed hook.
    function deployHookFor(
        uint256 projectId,
        JBDeploy721TiersHookConfig memory deployTiersHookConfig
    )
        external
        override
        returns (IJB721TiersHook newHook)
    {
        // Deploy the governance variant specified by the config.
        if (deployTiersHookConfig.governanceType == JB721GovernanceType.NONE) {
            newHook = IJB721TiersHook(Clones.clone(address(NO_GOVERNANCE)));
        } else if (deployTiersHookConfig.governanceType == JB721GovernanceType.ONCHAIN) {
            newHook = IJB721TiersHook(Clones.clone(address(ONCHAIN_GOVERNANCE)));
        } else {
            revert INVALID_GOVERNANCE_TYPE();
        }

        newHook.initialize(
            projectId,
            deployTiersHookConfig.name,
            deployTiersHookConfig.symbol,
            deployTiersHookConfig.rulesets,
            deployTiersHookConfig.baseUri,
            deployTiersHookConfig.tokenUriResolver,
            deployTiersHookConfig.contractUri,
            deployTiersHookConfig.tiersConfig,
            deployTiersHookConfig.store,
            deployTiersHookConfig.flags
        );

        // Transfer the hook's ownership to the address that called this function.
        JBOwnable(address(newHook)).transferOwnership(msg.sender);

        // Add the hook to the address registry. This contract's nonce starts at 1.
        ADDRESS_REGISTRY.registerAddress(address(this), ++_nonce);

        emit HookDeployed(projectId, newHook, deployTiersHookConfig.governanceType);

        return newHook;
    }
}
