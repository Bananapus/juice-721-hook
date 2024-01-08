// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "lib/forge-std/src/Test.sol";
import "../utils/ForTest_JB721TiersHook.sol";

import "src/JB721TiersHookDeployer.sol";
import "src/JB721TiersHook.sol";
import "src/JB721TiersHookStore.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "lib/juice-contracts-v4/src/libraries/JBRulesetMetadataResolver.sol";
import "lib/juice-contracts-v4/src/structs/JBTokenAmount.sol";
import "lib/juice-contracts-v4/src/structs/JBAfterRedeemRecordedContext.sol";
import "lib/juice-contracts-v4/src/structs/JBAfterPayRecordedContext.sol";
import "lib/juice-contracts-v4/src/structs/JBAfterRedeemRecordedContext.sol";
import "lib/juice-contracts-v4/src/structs/JBRedeemHookSpecification.sol";
import "lib/juice-contracts-v4/src/interfaces/terminal/IJBTerminal.sol";
import "lib/juice-contracts-v4/src/interfaces/IJBRulesetApprovalHook.sol";

import "src/structs/JBLaunchProjectConfig.sol";
import "src/structs/JBPayDataHookRulesetMetadata.sol";

import "lib/juice-address-registry/src/JBAddressRegistry.sol";

import "lib/juice-contracts-v4/src/libraries/JBCurrencyIds.sol";
import "lib/juice-contracts-v4/src/libraries/JBConstants.sol";

// TODO: Find new name for _tiers return variables
contract UnitTestSetup is Test {
    address beneficiary;
    address owner;
    address reserveBeneficiary;
    address mockJBController;
    address mockJBDirectory;
    address mockJBRulesets;
    address mockTokenUriResolver;
    address mockTerminalAddress;
    address mockJBProjects;
    address mockJBPermissions;

    string name = "NAME";
    string symbol = "SYM";
    string baseUri = "http://www.null.com/";
    string contractUri = "ipfs://null";
    string rulesetMemo = "meemoo";

    uint256 projectId = 69;

    uint256 constant SURPLUS = 10e18;
    // What's going on here? Shouldn't this be 4_000?
    uint256 constant REDEMPTION_RATE = JBConstants.MAX_RESERVED_RATE; // 40%

    JB721TierConfig defaultTierConfig;

    // NodeJS: function con(hash) { Buffer.from(bs58.decode(hash).slice(2)).toString('hex') }
    // JS;  0x${bs58.decode(hash).slice(2).toString('hex')})
    bytes32[] tokenUris = [
        bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
        bytes32(0xf5d60fc6f462f6176982833f5e2ca222a2ced265fa94e4ce1c477d74910250ed),
        bytes32(0x4258512cfb09993d9f3613a59ffc592a5593abf3c06ed57a22656c5fbca4de23),
        bytes32(0xae7035a8ef12433adbf4a55f2063696972bcf50434fe70ee6d8ab78f83e358c8),
        bytes32(0xae7035a8ef12433adbf4a55f2faabecff3446276fdbc6f6209e6bba25ee358c8),
        bytes32(0xae7035a8ef1242fc4b803a9284453843f278307462311f8b8b90fddfcbe358c8),
        bytes32(0xae824fb9f7de128f66cb5e224e4f8c65f37c479ee6ec7193c8741d6f997f5a18),
        bytes32(0xae7035a8f8d14617dd6d904265fe7d84a493c628385ffba7016d6463c852e8c8),
        bytes32(0xae7035a8ef12433adbf4a55f2063696972bcf50434fe70ee6d8ab78f74adbbf7),
        bytes32(0xae7035a8ef12433adbf4a55f2063696972bcf51c38098273db23452d955758c8)
    ];

    string[] theoreticHashes = [
        "QmWmyoMoctfbAaiEs2G46gpeUmhqFRDW6KWo64y5r581Vz",
        "QmetHutWQPz3qfu5jhTi1bqbRZXt8zAJaqqxkiJoJCX9DN",
        "QmSodj3RSrXKPy3WRFSPz8HRDVyRdrBtjxBfoiWBgtGugN",
        "Qma5atSTeoKJkcXe2R7gdmcvPvLJJkh2jd4cDZeM1wnFgK",
        "Qma5atSTeoKJkcXe2R7typcvPvLJJkh2jd4cDZeM1wnFgK",
        "Qma5atSTeoKJKSQSDFcgdmcvPvLJJkh2jd4cDZeM1wnFgK",
        "Qma5rtytgfdgzrg4345RFGdfbzert345rfgvs5YRtSTkcX",
        "Qma5atSTkcXe2R7gdmcvPvLJJkh2234234QcDZeM1wnFgK",
        "Qma5atSTeoKJkcXe2R7gdmcvPvLJJkh2jd4cDZeM1ZERze",
        "Qma5atSTeoKJkcXe2R7gdmcvPvLJLkh2jd4cDZeM1wnFgK"
    ];

    JB721TierConfig[] tiers;
    JB721TiersHookStore store;
    JB721TiersHook hook;
    JB721TiersHook noGovernanceOrigin; // noGovernanceOrigin
    JBAddressRegistry addressRegistry;
    JB721TiersHookDeployer jbHookDeployer;
    MetadataResolverHelper metadataHelper;

    address hook_i = address(bytes20(keccak256("hook_implementation")));

    event Mint(
        uint256 indexed tokenId,
        uint256 indexed tierId,
        address indexed beneficiary,
        uint256 totalAmountPaid,
        address caller
    );
    event MintReservedNft(uint256 indexed tokenId, uint256 indexed tierId, address indexed beneficiary, address caller);
    event AddTier(uint256 indexed tierId, JB721TierConfig tier, address caller);
    event RemoveTier(uint256 indexed tierId, address caller);
    event CleanTiers(address indexed nft, address caller);
    event AddPayCredits(
        uint256 indexed amount, uint256 indexed newTotalCredits, address indexed account, address caller
    );
    event UsePayCredits(
        uint256 indexed amount, uint256 indexed newTotalCredits, address indexed account, address caller
    );

    function setUp() public virtual {
        beneficiary = makeAddr("beneficiary");
        owner = makeAddr("owner");
        reserveBeneficiary = makeAddr("reserveBeneficiary");
        mockJBDirectory = makeAddr("mockJBDirectory");
        mockJBRulesets = makeAddr("mockJBRulesets");
        mockTerminalAddress = makeAddr("mockTerminalAddress");
        mockJBProjects = makeAddr("mockJBProjects");
        mockJBPermissions = makeAddr("mockJBPermissions");
        mockJBController = makeAddr("mockJBController");
        mockTokenUriResolver = address(0);

        vm.etch(mockJBDirectory, new bytes(0x69));
        vm.etch(mockJBRulesets, new bytes(0x69));
        vm.etch(mockTokenUriResolver, new bytes(0x69));
        vm.etch(mockTerminalAddress, new bytes(0x69));
        vm.etch(mockJBProjects, new bytes(0x69));
        vm.etch(mockJBController, new bytes(0x69));

        defaultTierConfig = JB721TierConfig({
            price: 0, // Use default price.
            initialSupply: 0, // Use default supply.
            votingUnits: 0, // Use default voting units.
            reserveFrequency: uint16(10), // Use default reserve frequency.
            reserveBeneficiary: reserveBeneficiary, // Use default beneficiary.
            encodedIPFSUri: bytes32(0), // Use default hashes array.
            category: type(uint24).max,
            allowOwnerMint: false,
            useReserveBeneficiaryAsDefault: false,
            transfersPausable: false,
            useVotingUnits: true
        });

        // Create 10 tiers, each with 100 NFTs available to mint.
        for (uint256 i; i < 10; i++) {
            tiers.push(
                JB721TierConfig({
                    price: uint104((i + 1) * 10),
                    initialSupply: uint32(100),
                    votingUnits: uint16(0),
                    reserveFrequency: uint16(0),
                    reserveBeneficiary: reserveBeneficiary,
                    encodedIPFSUri: tokenUris[i],
                    category: uint24(100),
                    allowOwnerMint: false,
                    useReserveBeneficiaryAsDefault: false,
                    transfersPausable: false,
                    useVotingUnits: true
                })
            );
        }
        vm.mockCall(
            mockJBRulesets,
            abi.encodeCall(IJBRulesets.currentOf, projectId),
            abi.encode(
                JBRuleset({
                    cycleNumber: 1,
                    id: block.timestamp,
                    basedOnId: 0,
                    start: block.timestamp,
                    duration: 600,
                    weight: 10e18,
                    decayRate: 0,
                    approvalHook: IJBRulesetApprovalHook(address(0)),
                    metadata: JBRulesetMetadataResolver.packRulesetMetadata(
                        JBRulesetMetadata({
                            reservedRate: 5000, //50%
                            redemptionRate: 5000, //50%
                            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
                            pausePay: false,
                            pauseCreditTransfers: false,
                            allowOwnerMinting: true,
                            allowTerminalMigration: false,
                            allowSetTerminals: false,
                            allowControllerMigration: false,
                            allowSetController: false,
                            holdFees: false,
                            useTotalSurplusForRedemptions: false,
                            useDataHookForPay: true,
                            useDataHookForRedeem: true,
                            dataHook: address(0),
                            metadata: 0x00
                        })
                        )
                })
            )
        );

        vm.mockCall(mockJBDirectory, abi.encodeWithSelector(IJBDirectory.PROJECTS.selector), abi.encode(mockJBProjects));

        vm.mockCall(
            mockJBDirectory, abi.encodeWithSelector(IJBPermissioned.PERMISSIONS.selector), abi.encode(mockJBPermissions)
        );

        noGovernanceOrigin = new JB721TiersHook(IJBDirectory(mockJBDirectory), IJBPermissions(mockJBPermissions));

        JBGoverned721TiersHook onchainGovernance =
            new JBGoverned721TiersHook(IJBDirectory(mockJBDirectory), IJBPermissions(mockJBPermissions));

        addressRegistry = new JBAddressRegistry();

        jbHookDeployer = new JB721TiersHookDeployer(onchainGovernance, noGovernanceOrigin, addressRegistry);

        store = new JB721TiersHookStore();

        JBDeploy721TiersHookConfig memory hookConfig = JBDeploy721TiersHookConfig(
            name,
            symbol,
            IJBRulesets(mockJBRulesets),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            JB721InitTiersConfig({
                tiers: tiers,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
                decimals: 18,
                prices: IJBPrices(address(0))
            }),
            address(0),
            store,
            JB721TiersHookFlags({
                preventOverspending: false,
                noNewTiersWithReserves: true,
                noNewTiersWithVotes: true,
                noNewTiersWithOwnerMinting: true
            }),
            JB721GovernanceType.NONE
        );

        hook = JB721TiersHook(address(jbHookDeployer.deployHookFor(projectId, hookConfig)));
        hook.transferOwnership(owner);

        metadataHelper = new MetadataResolverHelper();
    }

    function NATIVE() internal pure returns (uint256) {
        return JBCurrencyIds.NATIVE;
    }

    function USD() internal pure returns (uint256) {
        return JBCurrencyIds.USD;
    }

    function NATIVE_TOKEN() internal pure returns (address) {
        return JBConstants.NATIVE_TOKEN;
    }

    function MAX_FEE() internal pure returns (uint256) {
        return JBConstants.MAX_FEE;
    }

    function MAX_RESERVED_RATE() internal pure returns (uint256) {
        return JBConstants.MAX_RESERVED_RATE;
    }

    function MAX_REDEMPTION_RATE() internal pure returns (uint256) {
        return JBConstants.MAX_REDEMPTION_RATE;
    }

    function MAX_DECAY_RATE() internal pure returns (uint256) {
        return JBConstants.MAX_DECAY_RATE;
    }

    function SPLITS_TOTAL_PERCENT() internal pure returns (uint256) {
        return JBConstants.SPLITS_TOTAL_PERCENT;
    }

    function MAX_FEE_DISCOUNT() internal pure returns (uint256) {
        return JBConstants.MAX_FEE_DISCOUNT;
    }

    // ----------------
    // Internal helpers
    // ----------------
    // JB721Tier comparison

    function assertEq(JB721Tier memory first, JB721Tier memory second) internal {
        assertEq(first.id, second.id);
        assertEq(first.price, second.price);
        assertEq(first.remainingSupply, second.remainingSupply);
        assertEq(first.initialSupply, second.initialSupply);
        assertEq(first.votingUnits, second.votingUnits);
        assertEq(first.reserveFrequency, second.reserveFrequency);
        assertEq(first.reserveBeneficiary, second.reserveBeneficiary);
        assertEq(first.encodedIPFSUri, second.encodedIPFSUri);
    }

    // JB721Tier Array comparison
    function assertEq(JB721Tier[] memory first, JB721Tier[] memory second) internal {
        assertEq(first.length, second.length);
        for (uint256 i; i < first.length; i++) {
            assertEq(first[i].id, second[i].id);
            assertEq(first[i].price, second[i].price);
            assertEq(first[i].remainingSupply, second[i].remainingSupply);
            assertEq(first[i].initialSupply, second[i].initialSupply);
            assertEq(first[i].votingUnits, second[i].votingUnits);
            assertEq(first[i].reserveFrequency, second[i].reserveFrequency);
            assertEq(first[i].reserveBeneficiary, second[i].reserveBeneficiary);
            assertEq(first[i].encodedIPFSUri, second[i].encodedIPFSUri);
        }
    }

    function mockAndExpect(address target, bytes memory _calldata, bytes memory returnData) internal {
        vm.mockCall(target, _calldata, returnData);
        vm.expectCall(target, _calldata);
    }

    // Generate `tokenId`s based on token number and tier
    function _generateTokenId(uint256 tierId, uint256 tokenNumber) internal pure returns (uint256) {
        return (tierId * 1_000_000_000) + tokenNumber;
    }

    // Check if every elements from smol is in bigg.
    function _isIn(JB721Tier[] memory smol, JB721Tier[] memory bigg) internal returns (bool) {
        // smol cannot be bigger than bigg.
        if (smol.length > bigg.length) {
            emit log("_isIn: smol too big");
            return false;
        }
        if (smol.length == 0) return true;
        uint256 count;
        // Iterate on every smol element.
        for (uint256 smolIter; smolIter < smol.length; smolIter++) {
            // Compare it with every bigg element until...
            for (uint256 biggIter; biggIter < bigg.length; biggIter++) {
                // ... the same element is found, then break to go to the next smol element.
                if (_compareTiers(smol[smolIter], bigg[biggIter])) {
                    count += smolIter + 1; // 1-indexed, as the length.
                    break;
                }
            }
        }
        // Ensure that all the smol indexes have been iterated on (i.e. we've seen (smol.length)! elements).
        if (count == (smol.length * (smol.length + 1)) / 2) {
            return true;
        } else {
            emit log("_isIn: incomplete inclusion");
            emit log_uint(count);
            emit log_uint(smol.length);
            return false;
        }
    }

    function _compareTiers(JB721Tier memory first, JB721Tier memory second) internal pure returns (bool) {
        // Use this for quick debug:
        // if(first.id != second.id) emit log_string("compareTiers:id");

        // if(first.price != second.price) emit log_string("compareTiers:price");

        // if(first.remainingSupply != second.remainingSupply) emit log_string("compareTiers:remainingSupply");

        // if(first.initialSupply != second.initialSupply) emit log_string("compareTiers:initialSupply");

        // if(first.votingUnits != second.votingUnits) {
        //     emit log("compareTiers:votingUnits");
        //     emit log_uint(first.votingUnits);
        //     emit log_uint(second.votingUnits);
        // }

        // if(first.reserveFrequency != second.reserveFrequency) emit log_string("compareTiers:reserveFrequency");

        // if(first.reserveBeneficiary != second.reserveBeneficiary) emit
        // log_string("compareTiers:reserveBeneficiary");

        // if(first.encodedIPFSUri != second.encodedIPFSUri) {
        //     emit log_string("compareTiers:encodedIPFSUri");
        //     emit log_bytes32(first.encodedIPFSUri);
        //     emit log_bytes32(second.encodedIPFSUri);
        // }

        // if(keccak256(abi.encodePacked(first.resolvedUri)) != keccak256(abi.encodePacked(second.resolvedUri))) emit
        // log_string("compareTiers:uri");

        return (
            first.id == second.id && first.price == second.price && first.remainingSupply == second.remainingSupply
                && first.initialSupply == second.initialSupply && first.votingUnits == second.votingUnits
                && first.reserveFrequency == second.reserveFrequency
                && first.reserveBeneficiary == second.reserveBeneficiary && first.encodedIPFSUri == second.encodedIPFSUri
                && keccak256(abi.encodePacked(first.resolvedUri)) == keccak256(abi.encodePacked(second.resolvedUri))
        );
    }

    function _sortArray(uint256[] memory arr) internal pure returns (uint256[] memory) {
        for (uint256 i; i < arr.length; i++) {
            uint256 minIndex = i;
            uint256 minValue = arr[i];
            for (uint256 j = i; j < arr.length; j++) {
                if (arr[j] < minValue) {
                    minIndex = j;
                    minValue = arr[j];
                }
            }
            if (minIndex != i) (arr[i], arr[minIndex]) = (arr[minIndex], arr[i]);
        }
        return arr;
    }

    function _sortArray(uint16[] memory arr) internal pure returns (uint16[] memory) {
        for (uint256 i; i < arr.length; i++) {
            uint256 minIndex = i;
            uint16 minValue = arr[i];
            for (uint256 j = i; j < arr.length; j++) {
                if (arr[j] < minValue) {
                    minIndex = j;
                    minValue = arr[j];
                }
            }
            if (minIndex != i) (arr[i], arr[minIndex]) = (arr[minIndex], arr[i]);
        }
        return arr;
    }

    function _sortArray(uint8[] memory arr) internal pure returns (uint8[] memory) {
        for (uint256 i; i < arr.length; i++) {
            uint256 minIndex = i;
            uint8 minValue = arr[i];
            for (uint256 j = i; j < arr.length; j++) {
                if (arr[j] < minValue) {
                    minIndex = j;
                    minValue = arr[j];
                }
            }
            if (minIndex != i) (arr[i], arr[minIndex]) = (arr[minIndex], arr[i]);
        }
        return arr;
    }

    function _createArray(uint256 length, uint256 seed) internal pure returns (uint16[] memory) {
        uint16[] memory out = new uint16[](length);

        for (uint256 i; i < length; i++) {
            out[i] = uint16(uint256(keccak256(abi.encode(seed, i))));
        }

        return out;
    }

    function _createTiers(
        JB721TierConfig memory tierParams,
        uint256 numberOfTiers
    )
        internal
        view
        returns (JB721TierConfig[] memory tierConfigs, JB721Tier[] memory _tiers)
    {
        return _createTiers(tierParams, numberOfTiers, 0, new uint16[](numberOfTiers), 0);
    }

    function _createTiers(
        JB721TierConfig memory tierParams,
        uint256 numberOfTiers,
        uint256 categoryIncrement
    )
        internal
        view
        returns (JB721TierConfig[] memory tierConfigs, JB721Tier[] memory _tiers)
    {
        return _createTiers(tierParams, numberOfTiers, 0, new uint16[](numberOfTiers), categoryIncrement);
    }

    function _createTiers(
        JB721TierConfig memory tierParams,
        uint256 numberOfTiers,
        uint256 initialId,
        uint16[] memory floors
    )
        internal
        view
        returns (JB721TierConfig[] memory tierConfigs, JB721Tier[] memory _tiers)
    {
        return _createTiers(tierParams, numberOfTiers, initialId, floors, 0);
    }

    function _createTiers(
        JB721TierConfig memory tierConfig,
        uint256 numberOfTiers,
        uint256 initialId,
        uint16[] memory floors,
        uint256 categoryIncrement
    )
        internal
        view
        returns (JB721TierConfig[] memory tierConfigs, JB721Tier[] memory _tiers)
    {
        tierConfigs = new JB721TierConfig[](numberOfTiers);
        _tiers = new JB721Tier[](numberOfTiers);

        for (uint256 i; i < numberOfTiers; i++) {
            tierConfigs[i] = JB721TierConfig({
                price: floors[i] == 0 ? uint16((i + 1) * 10) : floors[i],
                initialSupply: tierConfig.initialSupply == 0 ? uint32(100) : tierConfig.initialSupply,
                votingUnits: tierConfig.votingUnits,
                reserveFrequency: tierConfig.reserveFrequency,
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: i < tokenUris.length ? tokenUris[i] : tokenUris[0],
                category: categoryIncrement == 0
                    ? tierConfig.category == type(uint24).max ? uint24(i * 2 + 1) : tierConfig.category
                    : uint24(i * 2 + categoryIncrement),
                allowOwnerMint: tierConfig.allowOwnerMint,
                useReserveBeneficiaryAsDefault: tierConfig.useReserveBeneficiaryAsDefault,
                transfersPausable: tierConfig.transfersPausable,
                useVotingUnits: tierConfig.useVotingUnits
            });

            _tiers[i] = JB721Tier({
                id: initialId + i + 1,
                price: tierConfigs[i].price,
                remainingSupply: tierConfigs[i].initialSupply,
                initialSupply: tierConfigs[i].initialSupply,
                votingUnits: tierConfigs[i].votingUnits,
                reserveFrequency: tierConfigs[i].reserveFrequency,
                reserveBeneficiary: tierConfigs[i].reserveBeneficiary,
                encodedIPFSUri: tierConfigs[i].encodedIPFSUri,
                category: tierConfigs[i].category,
                allowOwnerMint: tierConfigs[i].allowOwnerMint,
                transfersPausable: tierConfigs[i].transfersPausable,
                resolvedUri: defaultTierConfig.encodedIPFSUri == bytes32(0)
                    ? ""
                    : string(abi.encodePacked("resolverURI", _generateTokenId(initialId + i + 1, 0)))
            });
        }
    }

    function _addDeleteTiers(
        JB721TiersHook tiersHook,
        uint256 currentNumberOfTiers,
        uint256 numberOfTiersToRemove,
        JB721TierConfig[] memory tiersToAdd
    )
        internal
        returns (uint256)
    {
        uint256 newNumberOfTiers = currentNumberOfTiers;
        uint256[] memory tiersToRemove = new uint256[](numberOfTiersToRemove);

        for (uint256 i; i < numberOfTiersToRemove && newNumberOfTiers != 0; i++) {
            tiersToRemove[i] = currentNumberOfTiers - i - 1;
            newNumberOfTiers--;
        }

        newNumberOfTiers += tiersToAdd.length;

        vm.startPrank(owner);
        tiersHook.adjustTiers(tiersToAdd, tiersToRemove);
        tiersHook.STORE().cleanTiers(address(tiersHook));
        vm.stopPrank();

        JB721Tier[] memory storedTiers =
            tiersHook.STORE().tiersOf(address(tiersHook), new uint256[](0), false, 0, newNumberOfTiers);
        assertEq(storedTiers.length, newNumberOfTiers);

        return newNumberOfTiers;
    }

    function _initializeDelegateDefaultTiers(uint256 initialNumberOfTiers) internal returns (JB721TiersHook) {
        return _initializeDelegateDefaultTiers(
            initialNumberOfTiers, false, uint32(uint160(JBConstants.NATIVE_TOKEN)), 18, address(0)
        );
    }

    function _initializeDelegateDefaultTiers(
        uint256 initialNumberOfTiers,
        bool preventOverspending
    )
        internal
        returns (JB721TiersHook)
    {
        return _initializeDelegateDefaultTiers(
            initialNumberOfTiers, preventOverspending, uint32(uint160(JBConstants.NATIVE_TOKEN)), 18, address(0)
        );
    }

    function _initializeDelegateDefaultTiers(
        uint256 initialNumberOfTiers,
        bool preventOverspending,
        uint48 currency,
        uint48 decimals,
        address oracle
    )
        internal
        returns (JB721TiersHook tiersHook)
    {
        // Initialize first tiers to add
        (JB721TierConfig[] memory tiersParams,) = _createTiers(defaultTierConfig, initialNumberOfTiers);

        // "Deploy" the hook
        vm.etch(hook_i, address(hook).code);
        tiersHook = JB721TiersHook(hook_i);

        // Deploy the hook store
        JB721TiersHookStore hookStore = new JB721TiersHookStore();

        // Initialize the hook, put the struc in memory for stack's sake
        JB721TiersHookFlags memory flags = JB721TiersHookFlags({
            preventOverspending: preventOverspending,
            noNewTiersWithReserves: false,
            noNewTiersWithVotes: false,
            noNewTiersWithOwnerMinting: false
        });

        JB721InitTiersConfig memory pricingParams = JB721InitTiersConfig({
            tiers: tiersParams,
            currency: currency,
            decimals: decimals,
            prices: IJBPrices(oracle)
        });

        tiersHook.initialize(
            projectId,
            name,
            symbol,
            IJBRulesets(mockJBRulesets),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            pricingParams,
            IJB721TiersHookStore(hookStore),
            flags
        );

        // Transfer ownership to owner
        tiersHook.transferOwnership(owner);
    }

    function _initializeForTestHook(uint256 initialNumberOfTiers) internal returns (ForTest_JB721TiersHook tiersHook) {
        // Initialize first tiers to add
        (JB721TierConfig[] memory tiersParams,) = _createTiers(defaultTierConfig, initialNumberOfTiers);

        // Deploy the For Test hook store
        ForTest_JB721TiersHookStore hookStore = new ForTest_JB721TiersHookStore();

        // Deploy the For Test hook
        tiersHook = new ForTest_JB721TiersHook(
            projectId,
            IJBDirectory(mockJBDirectory),
            name,
            symbol,
            IJBRulesets(mockJBRulesets),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            tiersParams,
            IJB721TiersHookStore(address(hookStore)),
            JB721TiersHookFlags({
                preventOverspending: false,
                noNewTiersWithReserves: false,
                noNewTiersWithVotes: false,
                noNewTiersWithOwnerMinting: true
            })
        );

        // Transfer ownership to owner
        tiersHook.transferOwnership(owner);
    }

    function createData()
        internal
        view
        returns (
            JBDeploy721TiersHookConfig memory tiered721DeployerData,
            JBLaunchProjectConfig memory launchProjectConfig
        )
    {
        string memory projectMetadata;
        JBPayDataHookRulesetConfig[] memory rulesetConfigurations;
        JBTerminalConfig[] memory terminalConfigurations;
        JBPayDataHookRulesetMetadata memory metadata;
        JBFundAccessLimitGroup[] memory fundAccessLimitGroups;
        JB721TierConfig[] memory tierParams = new JB721TierConfig[](10);
        for (uint256 i; i < 10; i++) {
            tierParams[i] = JB721TierConfig({
                price: uint104((i + 1) * 10),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(0),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[i],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: true
            });
        }
        tiered721DeployerData = JBDeploy721TiersHookConfig({
            name: name,
            symbol: symbol,
            rulesets: IJBRulesets(mockJBRulesets),
            baseUri: baseUri,
            tokenUriResolver: IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri: contractUri,
            tiersConfig: JB721InitTiersConfig({
                tiers: tierParams,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
                decimals: 18,
                prices: IJBPrices(address(0))
            }),
            reserveBeneficiary: reserveBeneficiary,
            store: store,
            flags: JB721TiersHookFlags({
                preventOverspending: false,
                noNewTiersWithReserves: true,
                noNewTiersWithVotes: true,
                noNewTiersWithOwnerMinting: true
            }),
            governanceType: JB721GovernanceType.NONE
        });

        projectMetadata = "myIPFSHash";

        metadata = JBPayDataHookRulesetMetadata({
            reservedRate: 5000, //50%
            redemptionRate: 5000, //50%
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            allowControllerMigration: false,
            allowSetController: false,
            holdFees: false,
            useTotalSurplusForRedemptions: false,
            useDataHookForRedeem: false,
            metadata: 0x00
        });

        rulesetConfigurations = new JBPayDataHookRulesetConfig[](1);
        rulesetConfigurations[0].mustStartAtOrAfter = 0;
        rulesetConfigurations[0].duration = 14;
        rulesetConfigurations[0].weight = 10 ** 18;
        rulesetConfigurations[0].decayRate = 450_000_000;
        rulesetConfigurations[0].approvalHook = IJBRulesetApprovalHook(address(0));
        rulesetConfigurations[0].metadata = metadata;
        rulesetConfigurations[0].fundAccessLimitGroups = fundAccessLimitGroups;

        terminalConfigurations = new JBTerminalConfig[](1);
        address[] memory tokensToAccept = new address[](1);
        tokensToAccept[0] = JBConstants.NATIVE_TOKEN;
        terminalConfigurations[0] =
            JBTerminalConfig({terminal: IJBTerminal(mockTerminalAddress), tokensToAccept: tokensToAccept});

        launchProjectConfig = JBLaunchProjectConfig({
            projectMetadata: projectMetadata,
            rulesetConfigurations: rulesetConfigurations,
            terminalConfigurations: terminalConfigurations,
            memo: rulesetMemo
        });
    }
}
