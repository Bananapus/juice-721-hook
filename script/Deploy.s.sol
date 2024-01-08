pragma solidity 0.8.23;

import "lib/forge-std/src/Script.sol";
import "lib/forge-std/src/StdJson.sol";
import "lib/forge-std/src/Test.sol";

import {IJBAddressRegistry} from "lib/juice-address-registry/src/interfaces/IJBAddressRegistry.sol";
import {IJBProjects} from "lib/juice-contracts-v4/src/interfaces/IJBProjects.sol";
import {IJBDirectory} from "lib/juice-contracts-v4/src/interfaces/IJBDirectory.sol";
import {IJBPermissions} from "lib/juice-contracts-v4/src/interfaces/IJBPermissions.sol";

import {JB721TiersHookDeployer} from "src/JB721TiersHookDeployer.sol";
import {JB721TiersHookProjectDeployer} from "src/JB721TiersHookProjectDeployer.sol";
import {JB721TiersHookStore} from "src/JB721TiersHookStore.sol";
import {JB721TiersHook} from "src/JB721TiersHook.sol";
import {JBGoverned721TiersHook} from "src/JBGoverned721TiersHook.sol";

contract DeployMainnet is Script {
    IJBDirectory jbDirectory = IJBDirectory(0x65572FB928b46f9aDB7cfe5A4c41226F636161ea);
    IJBPermissions jbOperatorStore = IJBPermissions(0x6F3C5afCa0c9eDf3926eF2dDF17c8ae6391afEfb);

    JB721TiersHookDeployer hookDeployer;
    JB721TiersHookProjectDeployer projectDeployer;
    JB721TiersHookStore store;

    function run() external {
        IJBAddressRegistry registry = IJBAddressRegistry(
            stdJson.readAddress(
                vm.readFile("lib/juice-address-registry/broadcast/Deploy.s.sol/1/run-latest.json"),
                ".transactions[0].contractAddress"
            )
        );

        // Make a static call for sanity check
        assert(registry.deployerOf(address(0)) == address(0));

        vm.startBroadcast();

        JB721TiersHook noGovernance = new JB721TiersHook(jbDirectory, jbOperatorStore);
        JBGoverned721TiersHook onchainGovernance = new JBGoverned721TiersHook(jbDirectory, jbOperatorStore);

        hookDeployer = new JB721TiersHookDeployer(onchainGovernance, noGovernance, registry);

        store = JB721TiersHookStore(0x615B5b50F1Fc591AAAb54e633417640d6F2773Fd);

        projectDeployer = new JB721TiersHookProjectDeployer(jbDirectory, hookDeployer, jbOperatorStore);

        console.log("registry ", address(registry));
        console.log("project deployer", address(projectDeployer));
        console.log("store ", address(store));
    }
}

contract DeployGoerli is Script {
    IJBDirectory jbDirectory = IJBDirectory(0x8E05bcD2812E1449f0EC3aE24E2C395F533d9A99);
    IJBPermissions jbOperatorStore = IJBPermissions(0x99dB6b517683237dE9C494bbd17861f3608F3585);

    bytes4 metadataPayHookId = bytes4("721P");
    bytes4 metadataRedeemHookId = bytes4("721R");

    JB721TiersHookDeployer hookDeployer;
    JB721TiersHookProjectDeployer projectDeployer;
    JB721TiersHookStore store;

    function run() external {
        IJBAddressRegistry registry = IJBAddressRegistry(
            stdJson.readAddress(
                vm.readFile("lib/juice-address-registry/broadcast/Deploy.s.sol/1/run-latest.json"),
                ".transactions[0].contractAddress"
            )
        );

        // Make a static call for sanity check
        assert(registry.deployerOf(address(0)) == address(0));

        vm.startBroadcast();

        JB721TiersHook noGovernance = new JB721TiersHook(jbDirectory, jbOperatorStore);
        JBGoverned721TiersHook onchainGovernance = new JBGoverned721TiersHook(jbDirectory, jbOperatorStore);

        hookDeployer = new JB721TiersHookDeployer(onchainGovernance, noGovernance, registry);

        store = JB721TiersHookStore(0x155B49f303443a3334bB2EF42E10C628438a0656);

        projectDeployer = new JB721TiersHookProjectDeployer(jbDirectory, hookDeployer, jbOperatorStore);

        console.log("registry ", address(registry));
        console.log("project deployer", address(projectDeployer));
        console.log("store ", address(store));
    }
}
