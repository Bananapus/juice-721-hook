// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../utils/ForTest_JBTiered721Delegate.sol";

import "../../JBTiered721DelegateDeployer.sol";
import "../../JBTiered721Delegate.sol";
import "../../JBTiered721DelegateStore.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBFundingCycleMetadataResolver.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBTokenAmount.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBDidRedeemData3_1_1.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBDidPayData3_1_1.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBDidRedeemData3_1_1.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBRedemptionDelegateAllocation3_1_1.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPaymentTerminal.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBFundingCycleBallot.sol";

import "../../structs/JBLaunchProjectData.sol";


import "@jbx-protocol/juice-delegates-registry/src/JBDelegatesRegistry.sol";

import "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBCurrencies.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBConstants.sol";
import "@jbx-protocol/juice-contracts-v3/contracts/libraries/JBTokens.sol";

bytes4 constant PAY_DELEGATE_ID = bytes4(hex"70");
bytes4 constant REDEEM_DELEGATE_ID = bytes4(hex"71");

contract UnitTestSetup is Test {
    address beneficiary;
    address owner;
    address reserveBeneficiary;
    address mockJBController;
    address mockJBDirectory;
    address mockJBFundingCycleStore;
    address mockTokenUriResolver;
    address mockTerminalAddress;
    address mockJBProjects;
    address mockJBOperatorStore;
    
    string name = "NAME";
    string symbol = "SYM";
    string baseUri = "http://www.null.com/";
    string contractUri = "ipfs://null";
    string fcMemo = "meemoo";

    uint256 projectId = 69;

    uint256 constant OVERFLOW = 10e18;
    uint256 constant REDEMPTION_RATE = JBConstants.MAX_RESERVED_RATE; // 40%

    JB721TierParams defaultTierParams;

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
    
    string[] theoricHashes = [
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

    JB721TierParams[] tiers;
    JBTiered721DelegateStore store;
    JBTiered721Delegate delegate;
    JBTiered721Delegate noGovernanceOrigin; // noGovernanceOrigin
    JBDelegatesRegistry delegatesRegistry;
    JBTiered721DelegateDeployer jbDelegateDeployer;
    JBDelegateMetadataHelper metadataHelper;

    address delegate_i = address(bytes20(keccak256("delegate_implementation")));

    event Mint(
        uint256 indexed tokenId,
        uint256 indexed tierId,
        address indexed beneficiary,
        uint256 totalAmountContributed,
        address caller
    );
    event MintReservedToken(
        uint256 indexed tokenId, uint256 indexed tierId, address indexed beneficiary, address caller
    );
    event AddTier(uint256 indexed tierId, JB721TierParams tier, address caller);
    event RemoveTier(uint256 indexed tierId, address caller);
    event CleanTiers(address indexed nft, address caller);
    event AddCredits(
        uint256 indexed changeAmount, uint256 indexed newTotalCredits, address indexed account, address caller
    );
    event UseCredits(
        uint256 indexed changeAmount, uint256 indexed newTotalCredits, address indexed account, address caller
    );

    function setUp() public virtual {
        beneficiary = makeAddr("beneficiary");
        owner = makeAddr("owner");
        reserveBeneficiary = makeAddr("reserveBeneficiary");
        mockJBDirectory = makeAddr("mockJBDirectory");
        mockJBFundingCycleStore = makeAddr("mockJBFundingCycleStore");
        mockTerminalAddress = makeAddr("mockTerminalAddress");
        mockJBProjects = makeAddr("mockJBProjects");
        mockJBOperatorStore = makeAddr("mockJBOperatorStore");
        mockJBController = makeAddr("mockJBController");
        mockTokenUriResolver = address(0);

        vm.etch(mockJBDirectory, new bytes(0x69));
        vm.etch(mockJBFundingCycleStore, new bytes(0x69));
        vm.etch(mockTokenUriResolver, new bytes(0x69));
        vm.etch(mockTerminalAddress, new bytes(0x69));
        vm.etch(mockJBProjects, new bytes(0x69));
        vm.etch(mockJBController, new bytes(0x69));

        defaultTierParams = JB721TierParams({
                price: 0, // use defaut prices
                initialQuantity: 0, // use default Qt
                votingUnits: 0, // default voting units
                reservedRate: uint16(10), // default rr
                reservedTokenBeneficiary: reserveBeneficiary, // default beneficiary
                encodedIPFSUri: bytes32(0), // default hashes array
                category: type(uint24).max,
                allowManualMint: false,
                shouldUseReservedTokenBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: true
            });

        // Create 10 tiers, each with 100 tokens available to mint
        for (uint256 i; i < 10; i++) {
            tiers.push(
                JB721TierParams({
                    price: uint104((i + 1) * 10),
                    initialQuantity: uint32(100),
                    votingUnits: uint16(0),
                    reservedRate: uint16(0),
                    reservedTokenBeneficiary: reserveBeneficiary,
                    encodedIPFSUri: tokenUris[i],
                    category: uint24(100),
                    allowManualMint: false,
                    shouldUseReservedTokenBeneficiaryAsDefault: false,
                    transfersPausable: false,
                    useVotingUnits: true
                })
            );
        }
        vm.mockCall(
            mockJBFundingCycleStore,
            abi.encodeCall(IJBFundingCycleStore.currentOf, projectId),
            abi.encode(
                JBFundingCycle({
                    number: 1,
                    configuration: block.timestamp,
                    basedOn: 0,
                    start: block.timestamp,
                    duration: 600,
                    weight: 10e18,
                    discountRate: 0,
                    ballot: IJBFundingCycleBallot(address(0)),
                    metadata: JBFundingCycleMetadataResolver.packFundingCycleMetadata(
                        JBFundingCycleMetadata({
                            global: JBGlobalFundingCycleMetadata({
                                allowSetTerminals: false,
                                allowSetController: false,
                                pauseTransfers: false
                            }),
                            reservedRate: 5000, //50%
                            redemptionRate: 5000, //50%
                            ballotRedemptionRate: 5000,
                            pausePay: false,
                            pauseDistributions: false,
                            pauseRedeem: false,
                            pauseBurn: false,
                            allowMinting: true,
                            allowTerminalMigration: false,
                            allowControllerMigration: false,
                            holdFees: false,
                            preferClaimedTokenOverride: false,
                            useTotalOverflowForRedemptions: false,
                            useDataSourceForPay: true,
                            useDataSourceForRedeem: true,
                            dataSource: address(0),
                            metadata: 0x00
                        })
                        )
                })
            )
        );

        vm.mockCall(mockJBDirectory, abi.encodeWithSelector(IJBDirectory.projects.selector), abi.encode(mockJBProjects));

        vm.mockCall(
            mockJBDirectory, abi.encodeWithSelector(IJBOperatable.operatorStore.selector), abi.encode(mockJBOperatorStore)
        );

        noGovernanceOrigin = new JBTiered721Delegate(
            IJBDirectory(mockJBDirectory), 
            IJBOperatorStore(mockJBOperatorStore), 
            PAY_DELEGATE_ID, 
            REDEEM_DELEGATE_ID
        );

        JBTiered721GovernanceDelegate onchainGovernance = new JBTiered721GovernanceDelegate(
            IJBDirectory(mockJBDirectory), 
            IJBOperatorStore(mockJBOperatorStore), 
            PAY_DELEGATE_ID, 
            REDEEM_DELEGATE_ID
        );

        delegatesRegistry = new JBDelegatesRegistry(IJBDelegatesRegistry(address(0)));

        jbDelegateDeployer = new JBTiered721DelegateDeployer(
            onchainGovernance,
            noGovernanceOrigin,
            delegatesRegistry
        );

        store = new JBTiered721DelegateStore();

        JBDeployTiered721DelegateData memory delegateData = JBDeployTiered721DelegateData(
            name,
            symbol,
            IJBFundingCycleStore(mockJBFundingCycleStore),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            JB721PricingParams({tiers: tiers, currency: 1, decimals: 18, prices: IJBPrices(address(0))}),
            address(0),
            store,
            JBTiered721Flags({
                preventOverspending: false,
                lockReservedTokenChanges: true,
                lockVotingUnitChanges: true,
                lockManualMintingChanges: true
            }),
            JB721GovernanceType.NONE
        );

        delegate = JBTiered721Delegate(address(jbDelegateDeployer.deployDelegateFor(projectId, delegateData)));
        delegate.transferOwnership(owner);

        metadataHelper = new JBDelegateMetadataHelper();

    }

    function ETH() internal pure returns (uint256) {
        return JBCurrencies.ETH;
    }

    function USD() internal pure returns (uint256) {
        return JBCurrencies.USD;
    }

    function ETHToken() internal pure returns (address) {
        return JBTokens.ETH;
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

    function MAX_DISCOUNT_RATE() internal pure returns (uint256) {
        return JBConstants.MAX_DISCOUNT_RATE;
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
        assertEq(first.remainingQuantity, second.remainingQuantity);
        assertEq(first.initialQuantity, second.initialQuantity);
        assertEq(first.votingUnits, second.votingUnits);
        assertEq(first.reservedRate, second.reservedRate);
        assertEq(first.reservedTokenBeneficiary, second.reservedTokenBeneficiary);
        assertEq(first.encodedIPFSUri, second.encodedIPFSUri);
    }
    // JB721Tier Array comparison

    function assertEq(JB721Tier[] memory first, JB721Tier[] memory second) internal {
        assertEq(first.length, second.length);
        for (uint256 i; i < first.length; i++) {
            assertEq(first[i].id, second[i].id);
            assertEq(first[i].price, second[i].price);
            assertEq(first[i].remainingQuantity, second[i].remainingQuantity);
            assertEq(first[i].initialQuantity, second[i].initialQuantity);
            assertEq(first[i].votingUnits, second[i].votingUnits);
            assertEq(first[i].reservedRate, second[i].reservedRate);
            assertEq(first[i].reservedTokenBeneficiary, second[i].reservedTokenBeneficiary);
            assertEq(first[i].encodedIPFSUri, second[i].encodedIPFSUri);
        }
    }

    function mockAndExpect(address _target, bytes memory _calldata, bytes memory _returnData) internal {
        vm.mockCall(_target, _calldata, _returnData);
        vm.expectCall(_target, _calldata);
    }

    // Generate tokenId's based on token number and tier
    function _generateTokenId(uint256 _tierId, uint256 _tokenNumber) internal pure returns (uint256) {
        return (_tierId * 1_000_000_000) + _tokenNumber;
    }
    // Check if every elements from smol are in bigg

    function _isIn(JB721Tier[] memory smol, JB721Tier[] memory bigg) internal returns (bool) {
        // Cannot be oversized
        if (smol.length > bigg.length) {
            emit log("_isIn: smol too big");
            return false;
        }
        if (smol.length == 0) return true;
        uint256 count;
        // Iterate on every smol elements
        for (uint256 smolIter; smolIter < smol.length; smolIter++) {
            // Compare it with every bigg element until...
            for (uint256 biggIter; biggIter < bigg.length; biggIter++) {
                // ... the same element is found -> break to go to the next smol element
                if (_compareTiers(smol[smolIter], bigg[biggIter])) {
                    count += smolIter + 1; // 1-indexed, as the length
                    break;
                }
            }
        }
        // Insure all the smoll indexes have been iterated on (ie we've seen (smoll.length)! elements)
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
        
        // if(first.remainingQuantity != second.remainingQuantity) emit log_string("compareTiers:remainingQuantity");
        
        // if(first.initialQuantity != second.initialQuantity) emit log_string("compareTiers:initialQuantity");
        
        // if(first.votingUnits != second.votingUnits) {
        //     emit log("compareTiers:votingUnits");
        //     emit log_uint(first.votingUnits);
        //     emit log_uint(second.votingUnits);
        // }
        
        // if(first.reservedRate != second.reservedRate) emit log_string("compareTiers:reservedRate");
        
        // if(first.reservedTokenBeneficiary != second.reservedTokenBeneficiary) emit log_string("compareTiers:reservedTokenBeneficiary");
        
        // if(first.encodedIPFSUri != second.encodedIPFSUri) {
        //     emit log_string("compareTiers:encodedIPFSUri");
        //     emit log_bytes32(first.encodedIPFSUri);
        //     emit log_bytes32(second.encodedIPFSUri);
        // }
        
        // if(keccak256(abi.encodePacked(first.resolvedUri)) != keccak256(abi.encodePacked(second.resolvedUri))) emit log_string("compareTiers:uri");
        
        return (
            first.id == second.id && first.price == second.price && first.remainingQuantity == second.remainingQuantity
                && first.initialQuantity == second.initialQuantity && first.votingUnits == second.votingUnits
                && first.reservedRate == second.reservedRate
                && first.reservedTokenBeneficiary == second.reservedTokenBeneficiary
                && first.encodedIPFSUri == second.encodedIPFSUri
                && keccak256(abi.encodePacked(first.resolvedUri)) == keccak256(abi.encodePacked(second.resolvedUri))
        );
    }

    function _sortArray(uint256[] memory _in) internal pure returns (uint256[] memory) {
        for (uint256 i; i < _in.length; i++) {
            uint256 minIndex = i;
            uint256 minValue = _in[i];
            for (uint256 j = i; j < _in.length; j++) {
                if (_in[j] < minValue) {
                    minIndex = j;
                    minValue = _in[j];
                }
            }
            if (minIndex != i) (_in[i], _in[minIndex]) = (_in[minIndex], _in[i]);
        }
        return _in;
    }

    function _sortArray(uint16[] memory _in) internal pure returns (uint16[] memory) {
        for (uint256 i; i < _in.length; i++) {
            uint256 minIndex = i;
            uint16 minValue = _in[i];
            for (uint256 j = i; j < _in.length; j++) {
                if (_in[j] < minValue) {
                    minIndex = j;
                    minValue = _in[j];
                }
            }
            if (minIndex != i) (_in[i], _in[minIndex]) = (_in[minIndex], _in[i]);
        }
        return _in;
    }

    function _sortArray(uint8[] memory _in) internal pure returns (uint8[] memory) {
        for (uint256 i; i < _in.length; i++) {
            uint256 minIndex = i;
            uint8 minValue = _in[i];
            for (uint256 j = i; j < _in.length; j++) {
                if (_in[j] < minValue) {
                    minIndex = j;
                    minValue = _in[j];
                }
            }
            if (minIndex != i) (_in[i], _in[minIndex]) = (_in[minIndex], _in[i]);
        }
        return _in;
    }

    function _createArray(uint256 _length, uint256 _seed) internal pure returns(uint16[] memory) {
        uint16[] memory _out = new uint16[](_length);

        for(uint256 i; i < _length; i++) {
            _out[i] = uint16(uint256(keccak256(abi.encode(_seed, i))));
        }

        return _out;
    }

    function _createTiers(JB721TierParams memory _tierParams, uint256 _numberOfTiers) internal view returns(JB721TierParams[] memory _tiersParams, JB721Tier[] memory _tiers) {
        return _createTiers(_tierParams, _numberOfTiers, 0, new uint16[](_numberOfTiers), 0);
    }

    function _createTiers(JB721TierParams memory _tierParams, uint256 _numberOfTiers, uint256 _categoryIncrement) internal view returns(JB721TierParams[] memory _tiersParams, JB721Tier[] memory _tiers) {
        return _createTiers(_tierParams, _numberOfTiers, 0, new uint16[](_numberOfTiers), _categoryIncrement);
    }

    function _createTiers(JB721TierParams memory _tierParams, uint256 _numberOfTiers, uint256 _initialId, uint16[] memory _floors) internal view returns(JB721TierParams[] memory _tiersParams, JB721Tier[] memory _tiers) {
        return _createTiers(_tierParams, _numberOfTiers, _initialId, _floors, 0);
    }

    function _createTiers(JB721TierParams memory _tierParams, uint256 _numberOfTiers, uint256 _initialId, uint16[] memory _floors, uint256 _categoryIncrement) internal view returns(JB721TierParams[] memory _tiersParams, JB721Tier[] memory _tiers) {
            _tiersParams = new JB721TierParams[](_numberOfTiers);
            _tiers = new JB721Tier[](_numberOfTiers);

            for (uint256 i; i < _numberOfTiers; i++) {
                _tiersParams[i] = JB721TierParams({
                    price: _floors[i] == 0 ? uint16((i + 1) * 10) : _floors[i],
                    initialQuantity: _tierParams.initialQuantity == 0 ? uint32(100) : _tierParams.initialQuantity,
                    votingUnits: _tierParams.votingUnits,
                    reservedRate: _tierParams.reservedRate,
                    reservedTokenBeneficiary: reserveBeneficiary,
                    encodedIPFSUri: i < tokenUris.length ? tokenUris[i] : tokenUris[0],
                    category: _categoryIncrement == 0
                        ? _tierParams.category == type(uint24).max
                            ? uint24(i*2+1)
                            : _tierParams.category
                        : uint24(i * 2 + _categoryIncrement),
                    allowManualMint: _tierParams.allowManualMint,
                    shouldUseReservedTokenBeneficiaryAsDefault: _tierParams.shouldUseReservedTokenBeneficiaryAsDefault,
                    transfersPausable: _tierParams.transfersPausable,
                    useVotingUnits: _tierParams.useVotingUnits
                });

                _tiers[i] = JB721Tier({
                    id: _initialId + i + 1,
                    price: _tiersParams[i].price,
                    remainingQuantity: _tiersParams[i].initialQuantity,
                    initialQuantity: _tiersParams[i].initialQuantity,
                    votingUnits: _tiersParams[i].votingUnits,
                    reservedRate: _tiersParams[i].reservedRate,
                    reservedTokenBeneficiary: _tiersParams[i].reservedTokenBeneficiary,
                    encodedIPFSUri: _tiersParams[i].encodedIPFSUri,
                    category: _tiersParams[i].category,
                    allowManualMint: _tiersParams[i].allowManualMint,
                    transfersPausable: _tiersParams[i].transfersPausable,
                    resolvedUri: defaultTierParams.encodedIPFSUri == bytes32(0)
                        ? "" 
                        : string(abi.encodePacked("resolverURI", _generateTokenId(_initialId + i + 1, 0)))
                });
            }
    }
    function _addDeleteTiers(JBTiered721Delegate _delegate, uint256 _currentNumberOfTiers, uint256 _numberOfTiersToRemove, JB721TierParams[] memory _tiersToAdd) internal returns (uint256) {
            uint256 _newNumberOfTiers = _currentNumberOfTiers;
            uint256[] memory tiersToRemove = new uint256[](_numberOfTiersToRemove);
            
            for(uint256 i; i < _numberOfTiersToRemove && _newNumberOfTiers != 0; i++) {
                tiersToRemove[i] = _currentNumberOfTiers - i - 1;
                _newNumberOfTiers--;

            }

            _newNumberOfTiers += _tiersToAdd.length;

            vm.startPrank(owner);
            _delegate.adjustTiers(_tiersToAdd, tiersToRemove);
            _delegate.store().cleanTiers(address(_delegate));
            vm.stopPrank();

            JB721Tier[] memory _storedTiers = _delegate.store().tiersOf(
                address(_delegate), new uint256[](0), false, 0, _newNumberOfTiers
            );
            assertEq(_storedTiers.length, _newNumberOfTiers);

            return _newNumberOfTiers;
    }

    function _initializeDelegateDefaultTiers(uint256 _initialNumberOfTiers) internal returns(JBTiered721Delegate){
        return _initializeDelegateDefaultTiers(_initialNumberOfTiers, false, 1, 18, address(0));
    }

    function _initializeDelegateDefaultTiers(uint256 _initialNumberOfTiers, bool _preventOverspending) internal returns(JBTiered721Delegate){
        return _initializeDelegateDefaultTiers(_initialNumberOfTiers, _preventOverspending, 1, 18, address(0));
    }

    function _initializeDelegateDefaultTiers(uint256 _initialNumberOfTiers, bool _preventOverspending, uint48 _currency, uint48 _decimals, address _oracle) internal returns(JBTiered721Delegate _delegate){
        // Initialize first tiers to add
        (JB721TierParams[] memory _tiersParams,) = _createTiers(
            defaultTierParams,
            _initialNumberOfTiers);

        // "Deploy" the delegate
        vm.etch(delegate_i, address(delegate).code);
        _delegate = JBTiered721Delegate(delegate_i);

        // Deploy the delegate store        
        JBTiered721DelegateStore _store = new JBTiered721DelegateStore();

        // Initialize the delegate, put the struc in memory for stack's sake
        JBTiered721Flags memory _flags = JBTiered721Flags({
            preventOverspending: _preventOverspending,
            lockReservedTokenChanges: false,
            lockVotingUnitChanges: false,
            lockManualMintingChanges: false
        });

        JB721PricingParams memory _pricingParams = JB721PricingParams({
            tiers: _tiersParams,
            currency: _currency,
            decimals: _decimals,
            prices: IJBPrices(_oracle)
        });

        _delegate.initialize(
            projectId,
            name,
            symbol,
            IJBFundingCycleStore(mockJBFundingCycleStore),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            _pricingParams,
            IJBTiered721DelegateStore(_store),
            _flags
        );

        // Transfer ownership to owner
        _delegate.transferOwnership(owner);
    }

    function _initializeForTestDelegate(uint256 _initialNumberOfTiers) internal returns(ForTest_JBTiered721Delegate _delegate){
        // Initialize first tiers to add
        (JB721TierParams[] memory _tiersParams,) = _createTiers(
            defaultTierParams,
            _initialNumberOfTiers);

        // Deploy the For Test delegate store        
        ForTest_JBTiered721DelegateStore _store = new ForTest_JBTiered721DelegateStore();

        // Deploy the For Test delegate
        _delegate = new ForTest_JBTiered721Delegate(
            projectId,
            IJBDirectory(mockJBDirectory),
            name,
            symbol,
            IJBFundingCycleStore(mockJBFundingCycleStore),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            _tiersParams,
            IJBTiered721DelegateStore(address(_store)),
            JBTiered721Flags({
                preventOverspending: false,
                lockReservedTokenChanges: false,
                lockVotingUnitChanges: false,
                lockManualMintingChanges: true
            })
        );

        // Transfer ownership to owner
        _delegate.transferOwnership(owner);
    }


    function createData()
        internal
        view
        returns (
            JBDeployTiered721DelegateData memory tiered721DeployerData,
            JBLaunchProjectData memory launchProjectData
        )
    {
        JBProjectMetadata memory projectMetadata;
        JBFundingCycleData memory data;
        JBPayDataSourceFundingCycleMetadata memory metadata;
        JBGroupedSplits[] memory groupedSplits;
        JBFundAccessConstraints[] memory fundAccessConstraints;
        IJBPaymentTerminal[] memory terminals;
        JB721TierParams[] memory tierParams = new JB721TierParams[](10);
        for (uint256 i; i < 10; i++) {
            tierParams[i] = JB721TierParams({
                price: uint104((i + 1) * 10),
                initialQuantity: uint32(100),
                votingUnits: uint16(0),
                reservedRate: uint16(0),
                reservedTokenBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[i],
                category: uint24(100),
                allowManualMint: false,
                shouldUseReservedTokenBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: true
            });
        }
        tiered721DeployerData = JBDeployTiered721DelegateData({
            name: name,
            symbol: symbol,
            fundingCycleStore: IJBFundingCycleStore(mockJBFundingCycleStore),
            baseUri: baseUri,
            tokenUriResolver: IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri: contractUri,
            pricing: JB721PricingParams({tiers: tierParams, currency: 1, decimals: 18, prices: IJBPrices(address(0))}),
            reservedTokenBeneficiary: reserveBeneficiary,
            store: store,
            flags: JBTiered721Flags({
                preventOverspending: false,
                lockReservedTokenChanges: true,
                lockVotingUnitChanges: true,
                lockManualMintingChanges: true
            }),
            governanceType: JB721GovernanceType.NONE
        });


        projectMetadata = JBProjectMetadata({content: "myIPFSHash", domain: 1});
        data = JBFundingCycleData({
            duration: 14,
            weight: 10 ** 18,
            discountRate: 450_000_000,
            ballot: IJBFundingCycleBallot(address(0))
        });
        metadata = JBPayDataSourceFundingCycleMetadata({
            global: JBGlobalFundingCycleMetadata({
                allowSetTerminals: false,
                allowSetController: false,
                pauseTransfers: false
            }),
            reservedRate: 5000, //50%
            redemptionRate: 5000, //50%
            ballotRedemptionRate: 0,
            pausePay: false,
            pauseDistributions: false,
            pauseRedeem: false,
            pauseBurn: false,
            allowMinting: false,
            allowTerminalMigration: false,
            allowControllerMigration: false,
            holdFees: false,
            preferClaimedTokenOverride: false,
            useTotalOverflowForRedemptions: false,
            useDataSourceForRedeem: false,
            metadata: 0x00
        });
        launchProjectData = JBLaunchProjectData({
            projectMetadata: projectMetadata,
            data: data,
            metadata: metadata,
            mustStartAtOrAfter: 0,
            groupedSplits: groupedSplits,
            fundAccessConstraints: fundAccessConstraints,
            terminals: terminals,
            memo: fcMemo
        });
    }
}
