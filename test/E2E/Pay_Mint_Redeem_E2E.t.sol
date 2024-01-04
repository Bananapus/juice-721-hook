pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@jbx-protocol/juice-delegates-registry/src/JBDelegatesRegistry.sol";

import "../../JBTiered721Delegate.sol";
import "../../JBTiered721DelegateProjectDeployer.sol";
import "../../JBTiered721DelegateDeployer.sol";
import "../../JBTiered721DelegateStore.sol";

import "../utils/TestBaseWorkflow.sol";
import "../../interfaces/IJBTiered721Delegate.sol";
import {JBDelegateMetadataHelper} from '@jbx-protocol/juice-delegate-metadata-lib/src/JBDelegateMetadataHelper.sol';


contract TestJBTieredNFTRewardDelegateE2E is TestBaseWorkflow {
    using JBFundingCycleMetadataResolver for JBFundingCycle;

    address reserveBeneficiary = address(bytes20(keccak256("reserveBeneficiary")));

    JBTiered721Delegate noGovernance;

    JBDelegateMetadataHelper metadataHelper;

    event Mint(
        uint256 indexed tokenId,
        uint256 indexed tierId,
        address indexed beneficiary,
        uint256 totalAmountContributed,
        address caller
    );
    event Burn(uint256 indexed tokenId, address owner, address caller);

    string name = "NAME";
    string symbol = "SYM";
    string baseUri = "http://www.null.com/";
    string contractUri = "ipfs://null";
    //QmWmyoMoctfbAaiEs2G46gpeUmhqFRDW6KWo64y5r581Vz
    bytes32[] tokenUris = [
        bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
        bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
        bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
        bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
        bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
        bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
        bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
        bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
        bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89),
        bytes32(0x7D5A99F603F231D53A4F39D1521F98D2E8BB279CF29BEBFD0687DC98458E7F89)
    ];
    bytes4 payMetadataDelegateId = bytes4(hex'70');
    bytes4 redeemMetadataDelegateId = bytes4(hex'71');

    JBTiered721DelegateProjectDeployer deployer;
    JBDelegatesRegistry delegatesRegistry;

    function setUp() public override {
        super.setUp();
        noGovernance = new JBTiered721Delegate(_jbDirectory, _jbOperatorStore, payMetadataDelegateId, redeemMetadataDelegateId);
        JBTiered721GovernanceDelegate onchainGovernance = new JBTiered721GovernanceDelegate(
      _jbDirectory,
      _jbOperatorStore,
      payMetadataDelegateId,
      redeemMetadataDelegateId
    );
        delegatesRegistry = new JBDelegatesRegistry(IJBDelegatesRegistry(address(0)));
        JBTiered721DelegateDeployer delegateDeployer = new JBTiered721DelegateDeployer(
      onchainGovernance,
      noGovernance,
      delegatesRegistry
    );
        deployer = new JBTiered721DelegateProjectDeployer(
      IJBDirectory(_jbDirectory),
      delegateDeployer,
      IJBOperatorStore(_jbOperatorStore)
    );

    metadataHelper = new JBDelegateMetadataHelper();
    }

    function testDeployLaunchProjectAndAddToRegistry() external {
        (JBDeployTiered721DelegateData memory tiered721DeployerData, JBLaunchProjectData memory launchProjectData) =
            createData();
        uint256 projectId =
            deployer.launchProjectFor(_projectOwner, tiered721DeployerData, launchProjectData, _jbController);
        // Check: first project has the id 1?
        assertEq(projectId, 1);
        // Check: delegate added to registry?
        address _delegate = _jbFundingCycleStore.currentOf(projectId).dataSource();
        assertEq(delegatesRegistry.deployerOf(_delegate), address(deployer.delegateDeployer()));
    }

    function testMintOnPayIfOneTierIsPassed(uint256 valueSent) external {
        valueSent = bound(valueSent, 10, 2000);
        // Highest possible tier is 10
        uint256 highestTier = valueSent <= 100 ? (valueSent / 10) : 10;
        (JBDeployTiered721DelegateData memory tiered721DeployerData, JBLaunchProjectData memory launchProjectData) =
            createData();
        uint256 projectId =
            deployer.launchProjectFor(_projectOwner, tiered721DeployerData, launchProjectData, _jbController);
        // Craft the metadata: claim from the highest tier
        uint16[] memory rawMetadata = new uint16[](1);
        rawMetadata[0] = uint16(highestTier);

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(true, rawMetadata);

        // Pass the delegate id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = payMetadataDelegateId;

        // Generate the metadata
        bytes memory _delegateMetadata =  metadataHelper.createMetadata(_ids, _data);

        // Check: correct tier and id?
        vm.expectEmit(true, true, true, true);
        emit Mint(
            _generateTokenId(highestTier, 1),
            highestTier,
            _beneficiary,
            valueSent,
            address(_jbETHPaymentTerminal) // msg.sender
        );
        vm.prank(_caller);
        _jbETHPaymentTerminal.pay{value: valueSent}(
            projectId,
            100,
            address(0),
            _beneficiary,
            /* _minReturnedTokens */
            0,
            /* _preferClaimedTokens */
            false,
            /* _memo */
            "Take my money!",
            /* _delegateMetadata */
            _delegateMetadata
        );
        uint256 tokenId = _generateTokenId(highestTier, 1);
        // Check: NFT actually received?
        address NFTRewardDataSource = _jbFundingCycleStore.currentOf(projectId).dataSource();
        if (valueSent < 10) {
            assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), 0);
        } else {
            assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), 1);
        }
        // Second minted with leftover (if > lowest tier)?
        assertEq(IERC721(NFTRewardDataSource).ownerOf(tokenId), _beneficiary);
        assertEq(IJBTiered721Delegate(NFTRewardDataSource).firstOwnerOf(tokenId), _beneficiary);
        // Check: firstOwnerOf and ownerOf are correct after a transfer?
        vm.prank(_beneficiary);
        IERC721(NFTRewardDataSource).transferFrom(_beneficiary, address(696969420), tokenId);
        assertEq(IERC721(NFTRewardDataSource).ownerOf(tokenId), address(696969420));
        assertEq(IJBTiered721Delegate(NFTRewardDataSource).firstOwnerOf(tokenId), _beneficiary);
        // Check: same after a second transfer - 0xSTVG-style testing?
        vm.prank(address(696969420));
        IERC721(NFTRewardDataSource).transferFrom(address(696969420), address(123456789), tokenId);
        assertEq(IERC721(NFTRewardDataSource).ownerOf(tokenId), address(123456789));
        assertEq(IJBTiered721Delegate(NFTRewardDataSource).firstOwnerOf(tokenId), _beneficiary);
    }

    function testMintOnPayIfMultipleTiersArePassed() external {
        (JBDeployTiered721DelegateData memory tiered721DeployerData, JBLaunchProjectData memory launchProjectData) =
            createData();
        uint256 projectId =
            deployer.launchProjectFor(_projectOwner, tiered721DeployerData, launchProjectData, _jbController);
        // 5 first tier floors
        uint256 _amountNeeded = 50 + 40 + 30 + 20 + 10;
        uint16[] memory rawMetadata = new uint16[](5);
        // Mint one per tier for the first 5 tiers
        for (uint256 i = 0; i < 5; i++) {
            rawMetadata[i] = uint16(i + 1); // Not the tier 0
            // Check: correct tiers and ids?
            vm.expectEmit(true, true, true, true);
            emit Mint(
                _generateTokenId(i + 1, 1),
                i + 1,
                _beneficiary,
                _amountNeeded,
                address(_jbETHPaymentTerminal) // msg.sender
            );
        }

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(true, rawMetadata);

        // Pass the delegate id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = payMetadataDelegateId;

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        vm.prank(_caller);
        _jbETHPaymentTerminal.pay{value: _amountNeeded}(
            projectId,
            _amountNeeded,
            address(0),
            _beneficiary,
            /* _minReturnedTokens */
            0,
            /* _preferClaimedTokens */
            false,
            /* _memo */
            "Take my money!",
            /* _delegateMetadata */
            _delegateMetadata
        );

        // Check: NFT actually received?
        address NFTRewardDataSource = _jbFundingCycleStore.currentOf(projectId).dataSource();
        assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), 5);
        for (uint256 i = 1; i <= 5; i++) {
            uint256 tokenId = _generateTokenId(i, 1);
            assertEq(IJBTiered721Delegate(NFTRewardDataSource).firstOwnerOf(tokenId), _beneficiary);
            // Check: firstOwnerOf and ownerOf are correct after a transfer?
            vm.prank(_beneficiary);
            IERC721(NFTRewardDataSource).transferFrom(_beneficiary, address(696969420), tokenId);
            assertEq(IERC721(NFTRewardDataSource).ownerOf(tokenId), address(696969420));
            assertEq(IJBTiered721Delegate(NFTRewardDataSource).firstOwnerOf(tokenId), _beneficiary);
        }
    }

    function testNoMintOnPayWhenNotIncludingTierIds(uint256 valueSent) external {
        valueSent = bound(valueSent, 10, 2000);
        (JBDeployTiered721DelegateData memory tiered721DeployerData, JBLaunchProjectData memory launchProjectData) =
            createData();
        uint256 projectId =
            deployer.launchProjectFor(_projectOwner, tiered721DeployerData, launchProjectData, _jbController);
        address NFTRewardDataSource = _jbFundingCycleStore.currentOf(projectId).dataSource();
        bool _allowOverspending = true;
        uint16[] memory rawMetadata = new uint16[](0);
        bytes memory metadata =
            abi.encode(bytes32(0), bytes32(0), type(IJBTiered721Delegate).interfaceId, _allowOverspending, rawMetadata);
        vm.prank(_caller);
        _jbETHPaymentTerminal.pay{value: valueSent}(
            projectId,
            100,
            address(0),
            _beneficiary,
            /* _minReturnedTokens */
            0,
            /* _preferClaimedTokens */
            false,
            /* _memo */
            "Take my money!",
            /* _delegateMetadata */
            metadata
        );
        // Check: No NFT was minted
        assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), 0);
        // Check: User Received the credits
        assertEq(IJBTiered721Delegate(NFTRewardDataSource).creditsOf(_beneficiary), valueSent);
    }

    function testNoMintOnPayWhenNotIncludingMetadata(uint256 valueSent) external {
        valueSent = bound(valueSent, 10, 2000);
        (JBDeployTiered721DelegateData memory tiered721DeployerData, JBLaunchProjectData memory launchProjectData) =
            createData();
        uint256 projectId =
            deployer.launchProjectFor(_projectOwner, tiered721DeployerData, launchProjectData, _jbController);
        address NFTRewardDataSource = _jbFundingCycleStore.currentOf(projectId).dataSource();

        vm.prank(_caller);
        _jbETHPaymentTerminal.pay{value: valueSent}(
            projectId,
            100,
            address(0),
            _beneficiary,
            /* _minReturnedTokens */
            0,
            /* _preferClaimedTokens */
            false,
            /* _memo */
            "Take my money!",
            /* _delegateMetadata */
            new bytes(0)
        );
        // Check: No NFT was minted
        assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), 0);
        // Check: User Received the credits
        assertEq(IJBTiered721Delegate(NFTRewardDataSource).creditsOf(_beneficiary), valueSent);
    }

    // TODO This needs care (fuzz fails with insuf reserve for val=10)
    function testMintReservedToken() external {
        uint16 valueSent = 1500;
        uint256 highestTier = valueSent <= 100 ? (valueSent / 10) : 10;
        (JBDeployTiered721DelegateData memory tiered721DeployerData, JBLaunchProjectData memory launchProjectData) =
            createData();
        uint256 projectId =
            deployer.launchProjectFor(_projectOwner, tiered721DeployerData, launchProjectData, _jbController);
        address NFTRewardDataSource = _jbFundingCycleStore.currentOf(projectId).dataSource();
        // Check: 0 reserved token before any mint from a contribution?
        assertEq(
            IJBTiered721Delegate(NFTRewardDataSource).store().numberOfReservedTokensOutstandingFor(
                NFTRewardDataSource, highestTier
            ),
            0
        );
        // Check: cannot mint 0 reserved token?
        vm.expectRevert(abi.encodeWithSelector(JBTiered721DelegateStore.INSUFFICIENT_RESERVES.selector));
        vm.prank(_projectOwner);
        IJBTiered721Delegate(NFTRewardDataSource).mintReservesFor(highestTier, 1);
        uint16[] memory rawMetadata = new uint16[](1);
        rawMetadata[0] = uint16(highestTier); // reward tier

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(true, rawMetadata);

        // Pass the delegate id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = payMetadataDelegateId;

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        // Check: correct tier and id?
        vm.expectEmit(true, true, true, true);
        emit Mint(
            _generateTokenId(highestTier, 1), // First one
            highestTier,
            _beneficiary,
            valueSent,
            address(_jbETHPaymentTerminal) // msg.sender
        );
        vm.prank(_caller);
        _jbETHPaymentTerminal.pay{value: valueSent}(
            projectId,
            100,
            address(0),
            _beneficiary,
            /* _minReturnedTokens */
            0,
            /* _preferClaimedTokens */
            false,
            /* _memo */
            "Take my money!",
            /* _delegateMetadata */
            _delegateMetadata
        );
        // Check: new reserved one (1 minted == 1 reserved, due to rounding up)
        assertEq(
            IJBTiered721Delegate(NFTRewardDataSource).store().numberOfReservedTokensOutstandingFor(
                NFTRewardDataSource, highestTier
            ),
            1
        );

        JB721Tier memory _tierBeforeMintingReserves =
            JBTiered721Delegate(NFTRewardDataSource).store().tierOf(NFTRewardDataSource, highestTier, false);

        // Mint the reserved token
        vm.prank(_projectOwner);
        IJBTiered721Delegate(NFTRewardDataSource).mintReservesFor(highestTier, 1);
        // Check: NFT received?
        assertEq(IERC721(NFTRewardDataSource).balanceOf(reserveBeneficiary), 1);

        JB721Tier memory _tierAfterMintingReserves =
            JBTiered721Delegate(NFTRewardDataSource).store().tierOf(NFTRewardDataSource, highestTier, false);
        // the remaining tiers should reduce
        assertLt(_tierAfterMintingReserves.remainingQuantity, _tierBeforeMintingReserves.remainingQuantity);

        // Check: no more reserved token to mint?
        assertEq(
            IJBTiered721Delegate(NFTRewardDataSource).store().numberOfReservedTokensOutstandingFor(
                NFTRewardDataSource, highestTier
            ),
            0
        );
        // Check: cannot mint more reserved token?
        vm.expectRevert(abi.encodeWithSelector(JBTiered721DelegateStore.INSUFFICIENT_RESERVES.selector));
        vm.prank(_projectOwner);
        IJBTiered721Delegate(NFTRewardDataSource).mintReservesFor(highestTier, 1);
    }

    // Will:
    // - Mint token
    // - check the remaining reserved supply within the corresponding tier
    // - burn from that tier
    // - recheck the remaining reserved supply (which should be back to the initial one)
    function testRedeemToken(uint256 valueSent) external {
        valueSent = bound(valueSent, 10, 2000);
        // Highest possible tier is 10
        uint256 highestTier = valueSent <= 100 ? (valueSent / 10) : 10;
        (JBDeployTiered721DelegateData memory tiered721DeployerData, JBLaunchProjectData memory launchProjectData) =
            createData();
        uint256 projectId =
            deployer.launchProjectFor(_projectOwner, tiered721DeployerData, launchProjectData, _jbController);
        // Craft the metadata: claim from the highest tier
        bytes memory _delegateMetadata;
        bytes[] memory _data;
        bytes4[] memory _ids;
        {
            uint16[] memory rawMetadata = new uint16[](1);
            rawMetadata[0] = uint16(highestTier);
            
            // Build the metadata with the tiers to mint and the overspending flag
            _data = new bytes[](1);
            _data[0] = abi.encode(true, rawMetadata);

            // Pass the delegate id
            _ids = new bytes4[](1);
            _ids[0] = payMetadataDelegateId;

            // Generate the metadata
            _delegateMetadata = metadataHelper.createMetadata(_ids, _data);
        }
        vm.prank(_caller);
        _jbETHPaymentTerminal.pay{value: valueSent}(
            projectId,
            100, // _amount
            address(0), // _token
            _beneficiary,
            0, // _minReturnedTokens
            false, //_preferClaimedTokens
            "Take my money!", // _memo
            _delegateMetadata //_delegateMetadata
        );

        {
        uint256 tokenId = _generateTokenId(highestTier, 1);

        // Craft the metadata: redeem the tokenId
        uint256[] memory redemptionId = new uint256[](1);
        redemptionId[0] = tokenId;

        // Build the metadata with the tiers to redeem
        _data[0] = abi.encode(redemptionId);

        // Pass the delegate id
        _ids[0] = redeemMetadataDelegateId;

        // Generate the metadata
        _delegateMetadata = metadataHelper.createMetadata(_ids, _data);
        }

        address NFTRewardDataSource = _jbFundingCycleStore.currentOf(projectId).dataSource();
        // New token balance
        uint256 tokenBalance = IERC721(NFTRewardDataSource).balanceOf(_beneficiary);
        
        vm.prank(_beneficiary);
        _jbETHPaymentTerminal.redeemTokensOf({
            _holder: _beneficiary,
            _projectId: projectId,
            _tokenCount: 0,
            _token: address(0),
            _minReturnedTokens: 0,
            _beneficiary: payable(_beneficiary),
            _memo: "imma out of here",
            _metadata: _delegateMetadata
        });
        // Check: NFT actually redeemed?
        assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), tokenBalance - 1);
        // Check: Burn accounted?
        assertEq(
            IJBTiered721Delegate(NFTRewardDataSource).store().numberOfBurnedFor(NFTRewardDataSource, highestTier), 1
        );
        // Calculate if we are rounding up or not. Used to verify 'numberOfReservedTokensOutstandingFor'
        uint256 _rounding;
        {
            JB721Tier memory _tier =
                IJBTiered721Delegate(NFTRewardDataSource).store().tierOf(NFTRewardDataSource, highestTier, false);
            // '_reserveTokensMinted' is always 0 here
            uint256 _numberOfNonReservesMinted = _tier.initialQuantity - _tier.remainingQuantity;
            _rounding = _numberOfNonReservesMinted % _tier.reservedRate > 0 ? 1 : 0;
        }
        // Check: Reserved left to mint is ?
        assertEq(
            IJBTiered721Delegate(NFTRewardDataSource).store().numberOfReservedTokensOutstandingFor(
                NFTRewardDataSource, highestTier
            ),
            (tokenBalance / tiered721DeployerData.pricing.tiers[highestTier - 1].reservedRate + _rounding)
        );
    }

    // Will:
    // - Mint token
    // - check the remaining supply within the corresponding tier (highest tier == 10, reserved rate is maximum -> 5)
    // - burn all the corresponding token from that tier
    function testRedeemAll() external {
        (JBDeployTiered721DelegateData memory tiered721DeployerData, JBLaunchProjectData memory launchProjectData) =
            createData();
        uint256 tier = 10;
        uint256 floor = tiered721DeployerData.pricing.tiers[tier - 1].price;
        uint256 projectId =
            deployer.launchProjectFor(_projectOwner, tiered721DeployerData, launchProjectData, _jbController);
        // Craft the metadata: claim 5 from the tier
        uint16[] memory rawMetadata = new uint16[](5);
        for (uint256 i; i < rawMetadata.length; i++) {
            rawMetadata[i] = uint16(tier);
        }

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(true, rawMetadata);

        // Pass the delegate id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = payMetadataDelegateId;

        // Generate the metadata
        bytes memory _delegateMetadata =  metadataHelper.createMetadata(_ids, _data);

        vm.prank(_caller);
        _jbETHPaymentTerminal.pay{value: floor * rawMetadata.length}(
            projectId,
            100, // _amount
            address(0), // _token
            _beneficiary,
            0, // _minReturnedTokens
            false, //_preferClaimedTokens
            "Take my money!", // _memo
            _delegateMetadata //_delegateMetadata
        );
        address NFTRewardDataSource = _jbFundingCycleStore.currentOf(projectId).dataSource();
        // New token balance
        uint256 tokenBalance = IERC721(NFTRewardDataSource).balanceOf(_beneficiary);
        // Reserved token available to mint
        uint256 reservedOutstanding = IJBTiered721Delegate(NFTRewardDataSource).store()
            .numberOfReservedTokensOutstandingFor(NFTRewardDataSource, tier);
        // Check: token minted and outstanding reserved balances are correct (+1 as we're rounding up for non-null values)
        assertEq(rawMetadata.length, tokenBalance);
        assertEq(reservedOutstanding, (tokenBalance / tiered721DeployerData.pricing.tiers[tier - 1].reservedRate) + 1);
        // Craft the metadata to redeem the tokenId's
        uint256[] memory redemptionId = new uint256[](5);
        for (uint256 i; i < rawMetadata.length; i++) {
            uint256 tokenId = _generateTokenId(tier, i + 1);
            redemptionId[i] = tokenId;
        }

        // Build the metadata with the tiers to redeem
        _data[0] = abi.encode(redemptionId);

        // Pass the delegate id
        _ids[0] = redeemMetadataDelegateId;

        // Generate the metadata
        _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        vm.prank(_beneficiary);
        _jbETHPaymentTerminal.redeemTokensOf({
            _holder: _beneficiary,
            _projectId: projectId,
            _tokenCount: 0,
            _token: address(0),
            _minReturnedTokens: 0,
            _beneficiary: payable(_beneficiary),
            _memo: "imma out of here",
            _metadata: _delegateMetadata
        });
        // Check: NFT actually redeemed?
        assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), 0);
        // Check: Burn accounted?
        assertEq(IJBTiered721Delegate(NFTRewardDataSource).store().numberOfBurnedFor(NFTRewardDataSource, tier), 5);
        // Check: Reserved left to mint is back to 0
        assertEq(
            IJBTiered721Delegate(NFTRewardDataSource).store().numberOfReservedTokensOutstandingFor(
                NFTRewardDataSource, tier
            ),
            0
        );

        // Build the metadata with the tiers to mint and the overspending flag
        _data[0] = abi.encode(true, rawMetadata);

        // Pass the delegate id
        _ids[0] = payMetadataDelegateId;

        // Generate the metadata
        _delegateMetadata =  metadataHelper.createMetadata(_ids, _data);

        // Check: Can mint again the token previously burned
        vm.prank(_caller);
        _jbETHPaymentTerminal.pay{value: floor * rawMetadata.length}(
            projectId,
            100, // _amount
            address(0), // _token
            _beneficiary,
            0, // _minReturnedTokens
            false, //_preferClaimedTokens
            "Take my money!", // _memo
            _delegateMetadata //_delegateMetadata
        );
        // New token balance
        tokenBalance = IERC721(NFTRewardDataSource).balanceOf(_beneficiary);
        // Reserved token available to mint is back at prev value too
        reservedOutstanding = IJBTiered721Delegate(NFTRewardDataSource).store().numberOfReservedTokensOutstandingFor(
            NFTRewardDataSource, tier
        );
        // Check: token minted and outstanding reserved balances are correct (+1 as we're rounding up for non-null values)
        assertEq(rawMetadata.length, tokenBalance);
        assertEq(reservedOutstanding, (tokenBalance / tiered721DeployerData.pricing.tiers[tier - 1].reservedRate) + 1);
    }

    // ----- internal helpers ------
    // Create launchProjectFor(..) payload
    function createData()
        internal
        returns (
            JBDeployTiered721DelegateData memory tiered721DeployerData,
            JBLaunchProjectData memory launchProjectData
        )
    {
        JB721TierParams[] memory tierParams = new JB721TierParams[](10);
        for (uint256 i; i < 10; i++) {
            tierParams[i] = JB721TierParams({
                price: uint104((i + 1) * 10),
                initialQuantity: uint32(10),
                votingUnits: uint32((i + 1) * 10),
                reservedRate: 10,
                reservedTokenBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[i],
                category: uint24(100),
                allowManualMint: false,
                shouldUseReservedTokenBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: false
            });
        }
        tiered721DeployerData = JBDeployTiered721DelegateData({
            name: name,
            symbol: symbol,
            fundingCycleStore: _jbFundingCycleStore,
            baseUri: baseUri,
            tokenUriResolver: IJB721TokenUriResolver(address(0)),
            contractUri: contractUri,
            pricing: JB721PricingParams({tiers: tierParams, currency: 1, decimals: 18, prices: IJBPrices(address(0))}),
            reservedTokenBeneficiary: reserveBeneficiary,
            store: new JBTiered721DelegateStore(),
            flags: JBTiered721Flags({
                preventOverspending: false,
                lockReservedTokenChanges: false,
                lockVotingUnitChanges: false,
                lockManualMintingChanges: true
            }),
            governanceType: JB721GovernanceType.NONE
        });
        launchProjectData = JBLaunchProjectData({
            projectMetadata: _projectMetadata,
            data: _data,
            metadata: _metadata,
            mustStartAtOrAfter: 0,
            groupedSplits: _groupedSplits,
            fundAccessConstraints: _fundAccessConstraints,
            terminals: _terminals,
            memo: ""
        });
    }

    // Generate tokenId's based on token number and tier
    function _generateTokenId(uint256 _tierId, uint256 _tokenNumber) internal pure returns (uint256) {
        return (_tierId * 1_000_000_000) + _tokenNumber;
    }
}
