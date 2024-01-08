pragma solidity 0.8.23;

import "lib/juice-address-registry/src/JBAddressRegistry.sol";
import "lib/juice-contracts-v4/src/interfaces/IJBController.sol";
import "lib/juice-contracts-v4/src/interfaces/IJBRulesets.sol";
import "lib/juice-contracts-v4/src/interfaces/IJBPrices.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "src/JB721TiersHookProjectDeployer.sol";
import "src/JB721TiersHookStore.sol";
import "src/enums/JB721GovernanceType.sol";
import "src/interfaces/IJB721TiersHookProjectDeployer.sol";
import "src/structs/JBLaunchProjectConfig.sol";
import "src/structs/JB721InitTiersConfig.sol";

import "../utils/UnitTestSetup.sol";

contract TestJB721TiersHookProjectDeployer_Unit is UnitTestSetup {
    using stdStorage for StdStorage;

    // bytes4 PAY_HOOK_ID = bytes4(hex"70");
    // bytes4 REDEEM_HOOK_ID = bytes4(hex"71");

    IJB721TiersHookProjectDeployer deployer;

    function setUp() public override {
        super.setUp();

        deployer = new JB721TiersHookProjectDeployer(
            IJBDirectory(mockJBDirectory), jbHookDeployer, IJBPermissions(mockJBPermissions)
        );
    }

    function testLaunchProjectFor_shouldLaunchProject(uint256 previousProjectId) external {
        // Include launching the protocol project (1)
        previousProjectId = bound(previousProjectId, 0, type(uint88).max - 1);

        (JBDeploy721TiersHookConfig memory tiered721DeployerData, JBLaunchProjectConfig memory launchProjectConfig) =
            createData();

        // Mock and check
        mockAndExpect(
            mockJBDirectory, abi.encodeWithSelector(IJBDirectory.PROJECTS.selector), abi.encode(mockJBProjects)
        );
        mockAndExpect(mockJBProjects, abi.encodeWithSelector(IERC721.ownerOf.selector), abi.encode(owner));
        mockAndExpect(mockJBProjects, abi.encodeWithSelector(IJBProjects.count.selector), abi.encode(previousProjectId));
        mockAndExpect(
            mockJBController, abi.encodeWithSelector(IJBController.launchProjectFor.selector), abi.encode(true)
        );

        // Test: launch project
        uint256 _projectId = deployer.launchProjectFor(
            owner, tiered721DeployerData, launchProjectConfig, IJBController(mockJBController)
        );

        // Check: correct project id?
        assertEq(previousProjectId, _projectId - 1);
    }
}
