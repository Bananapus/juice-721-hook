/**
 * DEPRECATED - Use jbm for now
 */
pragma solidity 0.8.23;

// import 'src/interfaces/IJB721TiersHookProjectDeployer.sol';
// import 'src/JB721TiersHookStore.sol';
// import 'forge-std/Script.sol';

// // Latest NFTProjectDeployer
// address constant PROJECT_DEPLOYER = 0x36F2Edc39d593dF81e7B311a9Dd74De28A6B38B1;

// // JB721TiersHookStore
// address constant STORE = 0x41126eC99F8A989fEB503ac7bB4c5e5D40E06FA4;

// // Change values in setUp() and createData()
// contract RinkebyLaunchProjectFor is Script {
//   IJB721TiersHookProjectDeployer deployer =
//     IJB721TiersHookProjectDeployer(PROJECT_DEPLOYER);
//   IJBController jbController;
//   IJBDirectory jbDirectory;
//   IJBRulesets jbFundingCycleStore;
//   IJBTerminal[] _terminals;
//   JBFundAccessLimitGroup[] _fundAccessLimitGroups;

//   JB721TiersHookStore store;

//   string name;
//   string symbol;
//   string baseUri;
//   string contractUri;

//   address projectOwner;

//   function setUp() public {
//     projectOwner = msg.sender; // Change me
//     jbController = deployer.controller();
//     jbDirectory = jbController.DIRECTORY();
//     jbFundingCycleStore = jbController.rulesets();
//     name = ''; // Change me
//     symbol = '';
//     baseUri = '';
//     contractUri = '';
//   }

//   function run() external {
//     (
//       JBDeploy721TiersHookConfig memory tiered721DeployerData,
//       JBLaunchProjectConfig memory launchProjectConfig
//     ) = createData();

//     vm.startBroadcast();

//     uint256 projectId = deployer.launchProjectFor(
//       projectOwner,
//       tiered721DeployerData,
//       launchProjectConfig
//     );

//     console.log(projectId);
//   }

//   function createData()
//     internal
//     returns (
//       JBDeploy721TiersHookConfig memory tiered721DeployerData,
//       JBLaunchProjectConfig memory launchProjectConfig
//     )
//   {
//     // Project rulesetId
//     JBProjectMetadata memory projectMetadata = JBProjectMetadata({
//       content: 'QmdkypzHEZTPZUWe6FmfHLD6iSu9DebRcssFFM42cv5q8i',
//       domain: 0
//     });

//     JBRulesetConfig memory _config = JBRulesetConfig({ // TODO: fix this one if using this test
//       duration: 600,
//       weight: 1000 * 10**18,
//       discountRate: 450000000,
//       ballot: IJBRulesetApprovalHook(address(0))
//     });

//     JBPayDataHookRulesetMetadata memory _metadata = JBPayDataHookRulesetMetadata({
//       global: JBGlobalFundingCycleMetadata({
//         allowSetTerminals: false,
//         allowSetController: false,
//         pauseTransfers: false
//       }),
//       reservedRate: 5000,
//       redemptionRate: 5000, //50%
//       ballotRedemptionRate: 5000,
//       pausePay: false,
//       pauseDistributions: false,
//       pauseRedeem: false,
//       pauseBurn: false,
//       allowMinting: true,
//       allowTerminalMigration: false,
//       allowControllerMigration: false,
//       holdFees: false,
//       preferClaimedTokenOverride: false,
//       useTotalOverflowForRedemptions: false,
//       useDataSourceForRedeem: true,
//       metadata: 0
//     });

//     JBSplit[] memory _splits = new JBSplit[](1);
//     _splits[0] = JBSplit({
//       preferClaimed: false,
//       preferAddToBalance: false,
//       percent: 1000000000,
//       projectId: 0,
//       beneficiary: payable(projectOwner),
//       allocator: IJBSplitAllocator(address(0))
//     });

//     JBSplitGroup[] memory _splitGroups = new JBSplitGroup[](1);
//     _splitGroups[0] = JBSplitGroup({group: 1, splits: _splits});

//     _terminals.push(IJBTerminal(0x765A8b9a23F58Db6c8849315C04ACf32b2D55cF8));

//     _fundAccessLimitGroups.push(
//       JBFundAccessLimitGroup({
//         terminal: _terminals[0],
//         token: address(0x000000000000000000000000000000000000EEEe), // ETH
//         distributionLimit: 100 ether,
//         surplusAllowance: 0,
//         distributionLimitCurrency: 1, // ETH
//         surplusAllowanceCurrency: 1
//       })
//     );

//     // NFT Reward parameters
//     JB721TierConfig[] memory tiers = new JB721TierConfig[](3);

//     for (uint256 i; i < 3; i++) {
//       tiers[i] = JB721TierConfig({
//         price: uint80(i * 0.001 ether),
//         initialSupply: 100,
//         votingUnits: uint16(10 * i),
//         reserveFrequency: 1,
//         reserveBeneficiary: address(0),
//         royaltyRate: uint8(0),
//         royaltyBeneficiary: address(0),
//         encodedIPFSUri: 0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89,
//         category: 100,
//         allowOwnerMint: false,
//         useReserveBeneficiaryAsDefault: true,
//         shouldUseRoyaltyBeneficiaryAsDefault: true,
//         transfersPausable: false
//       });
//     }

//     tiered721DeployerData = JBDeploy721TiersHookConfig({
//       directory: jbDirectory,
//       name: name,
//       symbol: symbol,
//       rulesets: jbFundingCycleStore,
//       baseUri: baseUri,
//       tokenUriResolver: IJBTokenUriResolver(address(0)),
//       contractUri: contractUri,
//       tiersConfig: JB721InitTiersConfig({
//         tiers: tiers,
//         currency: 1,
//         decimals: 18,
//         prices: IJBPrices(address(0))
//       }),
//       reserveBeneficiary: msg.sender,
//       store: IJB721TiersHookStore(STORE),
//       flags: JB721TiersHookFlags({
// preventOverspending: false,
//         noNewTiersWithReserves: true,
//         noNewTiersWithVotes: true,
//         noNewTiersWithOwnerMinting: true
//       }),
//       governanceType: JB721GovernanceType.NONE
//     });

//     launchProjectConfig = JBLaunchProjectConfig({
//       projectMetadata: projectMetadata,
//       config: _config,
//       metadata: _metadata,
//       mustStartAtOrAfter: 0,
//       splitGroups: _splitGroups,
//       fundAccessLimitGroups: _fundAccessLimitGroups,
//       terminals: _terminals,
//       memo: ''
//     });
//   }
// }
