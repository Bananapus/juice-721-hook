pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "lib/juice-address-registry/src/JBAddressRegistry.sol";

import "src/JB721TiersHook.sol";
import "src/JB721TiersHookProjectDeployer.sol";
import "src/JB721TiersHookDeployer.sol";
import "src/JB721TiersHookStore.sol";

import "../utils/TestBaseWorkflow.sol";
import "src/interfaces/IJB721TiersHook.sol";
import {MetadataResolverHelper} from "lib/juice-contracts-v4/test/helpers/MetadataResolverHelper.sol";

contract TestJBTieredNFTRewardDelegateE2E is TestBaseWorkflow {
    using JBRulesetMetadataResolver for JBRuleset;

    address reserveBeneficiary = address(bytes20(keccak256("reserveBeneficiary")));

    JB721TiersHook noGovernance;

    MetadataResolverHelper metadataHelper;

    event Mint(
        uint256 indexed tokenId,
        uint256 indexed tierId,
        address indexed beneficiary,
        uint256 totalAmountPaid,
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
    bytes4 metadataPayHookId = bytes4(hex"70");
    bytes4 metadataRedeemHookId = bytes4(hex"71");

    JB721TiersHookProjectDeployer deployer;
    JBAddressRegistry addressRegistry;

    function setUp() public override {
        super.setUp();
        noGovernance = new JB721TiersHook(_jbDirectory, _jbPermissions, metadataPayHookId, metadataRedeemHookId);
        JBGoverned721TiersHook onchainGovernance =
            new JBGoverned721TiersHook(_jbDirectory, _jbPermissions, metadataPayHookId, metadataRedeemHookId);
        addressRegistry = new JBAddressRegistry(IJBAddressRegistry(address(0)));
        JB721TiersHookDeployer hookDeployer =
            new JB721TiersHookDeployer(onchainGovernance, noGovernance, addressRegistry);
        deployer = new JB721TiersHookProjectDeployer(
            IJBDirectory(_jbDirectory), hookDeployer, IJBPermissions(_jbPermissions)
        );

        metadataHelper = new MetadataResolverHelper();
    }

    function testDeployLaunchProjectAndAddToRegistry() external {
        (JBDeploy721TiersHookConfig memory tiered721DeployerData, JBLaunchProjectConfig memory launchProjectConfig) =
            createData();
        uint256 projectId =
            deployer.launchProjectFor(_projectOwner, tiered721DeployerData, launchProjectConfig, _jbController);
        // Check: first project has the id 1?
        assertEq(projectId, 1);
        // Check: hook added to registry?
        address _hook = _jbRulesets.currentOf(projectId).dataSource();
        assertEq(addressRegistry.deployerOf(_hook), address(deployer.hookDeployer()));
    }

    function testMintOnPayIfOneTierIsPassed(uint256 valueSent) external {
        valueSent = bound(valueSent, 10, 2000);
        // Highest possible tier is 10
        uint256 highestTier = valueSent <= 100 ? (valueSent / 10) : 10;
        (JBDeploy721TiersHookConfig memory tiered721DeployerData, JBLaunchProjectConfig memory launchProjectConfig) =
            createData();
        uint256 projectId =
            deployer.launchProjectFor(_projectOwner, tiered721DeployerData, launchProjectConfig, _jbController);
        // Craft the metadata: claim from the highest tier
        uint16[] memory rawMetadata = new uint16[](1);
        rawMetadata[0] = uint16(highestTier);

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(true, rawMetadata);

        // Pass the hook id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = metadataPayHookId;

        // Generate the metadata
        bytes memory _hookMetadata = metadataHelper.createMetadata(_ids, _data);

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
            /* _hookMetadata */
            _hookMetadata
        );
        uint256 tokenId = _generateTokenId(highestTier, 1);
        // Check: NFT actually received?
        address NFTRewardDataSource = _jbRulesets.currentOf(projectId).dataSource();
        if (valueSent < 10) {
            assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), 0);
        } else {
            assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), 1);
        }
        // Second minted with leftover (if > lowest tier)?
        assertEq(IERC721(NFTRewardDataSource).ownerOf(tokenId), _beneficiary);
        assertEq(IJB721TiersHook(NFTRewardDataSource).firstOwnerOf(tokenId), _beneficiary);
        // Check: firstOwnerOf and ownerOf are correct after a transfer?
        vm.prank(_beneficiary);
        IERC721(NFTRewardDataSource).transferFrom(_beneficiary, address(696_969_420), tokenId);
        assertEq(IERC721(NFTRewardDataSource).ownerOf(tokenId), address(696_969_420));
        assertEq(IJB721TiersHook(NFTRewardDataSource).firstOwnerOf(tokenId), _beneficiary);
        // Check: same after a second transfer - 0xSTVG-style testing?
        vm.prank(address(696_969_420));
        IERC721(NFTRewardDataSource).transferFrom(address(696_969_420), address(123_456_789), tokenId);
        assertEq(IERC721(NFTRewardDataSource).ownerOf(tokenId), address(123_456_789));
        assertEq(IJB721TiersHook(NFTRewardDataSource).firstOwnerOf(tokenId), _beneficiary);
    }

    function testMintOnPayIfMultipleTiersArePassed() external {
        (JBDeploy721TiersHookConfig memory tiered721DeployerData, JBLaunchProjectConfig memory launchProjectConfig) =
            createData();
        uint256 projectId =
            deployer.launchProjectFor(_projectOwner, tiered721DeployerData, launchProjectConfig, _jbController);
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

        // Pass the hook id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = metadataPayHookId;

        // Generate the metadata
        bytes memory _hookMetadata = metadataHelper.createMetadata(_ids, _data);

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
            /* _hookMetadata */
            _hookMetadata
        );

        // Check: NFT actually received?
        address NFTRewardDataSource = _jbRulesets.currentOf(projectId).dataSource();
        assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), 5);
        for (uint256 i = 1; i <= 5; i++) {
            uint256 tokenId = _generateTokenId(i, 1);
            assertEq(IJB721TiersHook(NFTRewardDataSource).firstOwnerOf(tokenId), _beneficiary);
            // Check: firstOwnerOf and ownerOf are correct after a transfer?
            vm.prank(_beneficiary);
            IERC721(NFTRewardDataSource).transferFrom(_beneficiary, address(696_969_420), tokenId);
            assertEq(IERC721(NFTRewardDataSource).ownerOf(tokenId), address(696_969_420));
            assertEq(IJB721TiersHook(NFTRewardDataSource).firstOwnerOf(tokenId), _beneficiary);
        }
    }

    function testNoMintOnPayWhenNotIncludingTierIds(uint256 valueSent) external {
        valueSent = bound(valueSent, 10, 2000);
        (JBDeploy721TiersHookConfig memory tiered721DeployerData, JBLaunchProjectConfig memory launchProjectConfig) =
            createData();
        uint256 projectId =
            deployer.launchProjectFor(_projectOwner, tiered721DeployerData, launchProjectConfig, _jbController);
        address NFTRewardDataSource = _jbRulesets.currentOf(projectId).dataSource();
        bool _allowOverspending = true;
        uint16[] memory rawMetadata = new uint16[](0);
        bytes memory metadata =
            abi.encode(bytes32(0), bytes32(0), type(IJB721TiersHook).interfaceId, _allowOverspending, rawMetadata);
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
            /* _hookMetadata */
            metadata
        );
        // Check: No NFT was minted
        assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), 0);
        // Check: User Received the credits
        assertEq(IJB721TiersHook(NFTRewardDataSource).NftCreditsOf(_beneficiary), valueSent);
    }

    function testNoMintOnPayWhenNotIncludingMetadata(uint256 valueSent) external {
        valueSent = bound(valueSent, 10, 2000);
        (JBDeploy721TiersHookConfig memory tiered721DeployerData, JBLaunchProjectConfig memory launchProjectConfig) =
            createData();
        uint256 projectId =
            deployer.launchProjectFor(_projectOwner, tiered721DeployerData, launchProjectConfig, _jbController);
        address NFTRewardDataSource = _jbRulesets.currentOf(projectId).dataSource();

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
            /* _hookMetadata */
            new bytes(0)
        );
        // Check: No NFT was minted
        assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), 0);
        // Check: User Received the credits
        assertEq(IJB721TiersHook(NFTRewardDataSource).NftCreditsOf(_beneficiary), valueSent);
    }

    // TODO This needs care (fuzz fails with insuf reserve for val=10)
    function testMintReservedNft() external {
        uint16 valueSent = 1500;
        uint256 highestTier = valueSent <= 100 ? (valueSent / 10) : 10;
        (JBDeploy721TiersHookConfig memory tiered721DeployerData, JBLaunchProjectConfig memory launchProjectConfig) =
            createData();
        uint256 projectId =
            deployer.launchProjectFor(_projectOwner, tiered721DeployerData, launchProjectConfig, _jbController);
        address NFTRewardDataSource = _jbRulesets.currentOf(projectId).dataSource();
        // Check: 0 reserved token before any mint from a contribution?
        assertEq(
            IJB721TiersHook(NFTRewardDataSource).STORE().numberOfPendingReservesFor(NFTRewardDataSource, highestTier), 0
        );
        // Check: cannot mint 0 reserved token?
        vm.expectRevert(abi.encodeWithSelector(JB721TiersHookStore.INSUFFICIENT_PENDING_RESERVES.selector));
        vm.prank(_projectOwner);
        IJB721TiersHook(NFTRewardDataSource).mintPendingReservesFor(highestTier, 1);
        uint16[] memory rawMetadata = new uint16[](1);
        rawMetadata[0] = uint16(highestTier); // reward tier

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(true, rawMetadata);

        // Pass the hook id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = metadataPayHookId;

        // Generate the metadata
        bytes memory _hookMetadata = metadataHelper.createMetadata(_ids, _data);

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
            /* _hookMetadata */
            _hookMetadata
        );
        // Check: new reserved one (1 minted == 1 reserved, due to rounding up)
        assertEq(
            IJB721TiersHook(NFTRewardDataSource).STORE().numberOfPendingReservesFor(NFTRewardDataSource, highestTier), 1
        );

        JB721Tier memory _tierBeforeMintingReserves =
            JB721TiersHook(NFTRewardDataSource).STORE().tierOf(NFTRewardDataSource, highestTier, false);

        // Mint the reserved token
        vm.prank(_projectOwner);
        IJB721TiersHook(NFTRewardDataSource).mintPendingReservesFor(highestTier, 1);
        // Check: NFT received?
        assertEq(IERC721(NFTRewardDataSource).balanceOf(reserveBeneficiary), 1);

        JB721Tier memory _tierAfterMintingReserves =
            JB721TiersHook(NFTRewardDataSource).STORE().tierOf(NFTRewardDataSource, highestTier, false);
        // the remaining tiers should reduce
        assertLt(_tierAfterMintingReserves.remainingSupply, _tierBeforeMintingReserves.remainingSupply);

        // Check: no more reserved token to mint?
        assertEq(
            IJB721TiersHook(NFTRewardDataSource).STORE().numberOfPendingReservesFor(NFTRewardDataSource, highestTier), 0
        );
        // Check: cannot mint more reserved token?
        vm.expectRevert(abi.encodeWithSelector(JB721TiersHookStore.INSUFFICIENT_PENDING_RESERVES.selector));
        vm.prank(_projectOwner);
        IJB721TiersHook(NFTRewardDataSource).mintPendingReservesFor(highestTier, 1);
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
        (JBDeploy721TiersHookConfig memory tiered721DeployerData, JBLaunchProjectConfig memory launchProjectConfig) =
            createData();
        uint256 projectId =
            deployer.launchProjectFor(_projectOwner, tiered721DeployerData, launchProjectConfig, _jbController);
        // Craft the metadata: claim from the highest tier
        bytes memory _hookMetadata;
        bytes[] memory _data;
        bytes4[] memory _ids;
        {
            uint16[] memory rawMetadata = new uint16[](1);
            rawMetadata[0] = uint16(highestTier);

            // Build the metadata with the tiers to mint and the overspending flag
            _data = new bytes[](1);
            _data[0] = abi.encode(true, rawMetadata);

            // Pass the hook id
            _ids = new bytes4[](1);
            _ids[0] = metadataPayHookId;

            // Generate the metadata
            _hookMetadata = metadataHelper.createMetadata(_ids, _data);
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
            _hookMetadata //_hookMetadata
        );

        {
            uint256 tokenId = _generateTokenId(highestTier, 1);

            // Craft the metadata: redeem the tokenId
            uint256[] memory redemptionId = new uint256[](1);
            redemptionId[0] = tokenId;

            // Build the metadata with the tiers to redeem
            _data[0] = abi.encode(redemptionId);

            // Pass the hook id
            _ids[0] = metadataRedeemHookId;

            // Generate the metadata
            _hookMetadata = metadataHelper.createMetadata(_ids, _data);
        }

        address NFTRewardDataSource = _jbRulesets.currentOf(projectId).dataSource();
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
            _metadata: _hookMetadata
        });
        // Check: NFT actually redeemed?
        assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), tokenBalance - 1);
        // Check: Burn accounted?
        assertEq(IJB721TiersHook(NFTRewardDataSource).STORE().numberOfBurnedFor(NFTRewardDataSource, highestTier), 1);
        // Calculate if we are rounding up or not. Used to verify 'numberOfPendingReservesFor'
        uint256 _rounding;
        {
            JB721Tier memory _tier =
                IJB721TiersHook(NFTRewardDataSource).STORE().tierOf(NFTRewardDataSource, highestTier, false);
            // '_reserveTokensMinted' is always 0 here
            uint256 _numberOfNonReservesMinted = _tier.initialSupply - _tier.remainingSupply;
            _rounding = _numberOfNonReservesMinted % _tier.reserveFrequency > 0 ? 1 : 0;
        }
        // Check: Reserved left to mint is ?
        assertEq(
            IJB721TiersHook(NFTRewardDataSource).STORE().numberOfPendingReservesFor(NFTRewardDataSource, highestTier),
            (tokenBalance / tiered721DeployerData.tiersconfig.tiers[highestTier - 1].reserveFrequency + _rounding)
        );
    }

    // Will:
    // - Mint token
    // - check the remaining supply within the corresponding tier (highest tier == 10, reserved rate is maximum -> 5)
    // - burn all the corresponding token from that tier
    function testRedeemAll() external {
        (JBDeploy721TiersHookConfig memory tiered721DeployerData, JBLaunchProjectConfig memory launchProjectConfig) =
            createData();
        uint256 tier = 10;
        uint256 floor = tiered721DeployerData.tiersconfig.tiers[tier - 1].price;
        uint256 projectId =
            deployer.launchProjectFor(_projectOwner, tiered721DeployerData, launchProjectConfig, _jbController);
        // Craft the metadata: claim 5 from the tier
        uint16[] memory rawMetadata = new uint16[](5);
        for (uint256 i; i < rawMetadata.length; i++) {
            rawMetadata[i] = uint16(tier);
        }

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(true, rawMetadata);

        // Pass the hook id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = metadataPayHookId;

        // Generate the metadata
        bytes memory _hookMetadata = metadataHelper.createMetadata(_ids, _data);

        vm.prank(_caller);
        _jbETHPaymentTerminal.pay{value: floor * rawMetadata.length}(
            projectId,
            100, // _amount
            address(0), // _token
            _beneficiary,
            0, // _minReturnedTokens
            false, //_preferClaimedTokens
            "Take my money!", // _memo
            _hookMetadata //_hookMetadata
        );
        address NFTRewardDataSource = _jbRulesets.currentOf(projectId).dataSource();
        // New token balance
        uint256 tokenBalance = IERC721(NFTRewardDataSource).balanceOf(_beneficiary);
        // Reserved token available to mint
        uint256 reservedOutstanding =
            IJB721TiersHook(NFTRewardDataSource).STORE().numberOfPendingReservesFor(NFTRewardDataSource, tier);
        // Check: token minted and outstanding reserved balances are correct (+1 as we're rounding up for non-null
        // values)
        assertEq(rawMetadata.length, tokenBalance);
        assertEq(
            reservedOutstanding, (tokenBalance / tiered721DeployerData.tiersconfig.tiers[tier - 1].reserveFrequency) + 1
        );
        // Craft the metadata to redeem the tokenId's
        uint256[] memory redemptionId = new uint256[](5);
        for (uint256 i; i < rawMetadata.length; i++) {
            uint256 tokenId = _generateTokenId(tier, i + 1);
            redemptionId[i] = tokenId;
        }

        // Build the metadata with the tiers to redeem
        _data[0] = abi.encode(redemptionId);

        // Pass the hook id
        _ids[0] = metadataRedeemHookId;

        // Generate the metadata
        _hookMetadata = metadataHelper.createMetadata(_ids, _data);

        vm.prank(_beneficiary);
        _jbETHPaymentTerminal.redeemTokensOf({
            _holder: _beneficiary,
            _projectId: projectId,
            _tokenCount: 0,
            _token: address(0),
            _minReturnedTokens: 0,
            _beneficiary: payable(_beneficiary),
            _memo: "imma out of here",
            _metadata: _hookMetadata
        });
        // Check: NFT actually redeemed?
        assertEq(IERC721(NFTRewardDataSource).balanceOf(_beneficiary), 0);
        // Check: Burn accounted?
        assertEq(IJB721TiersHook(NFTRewardDataSource).STORE().numberOfBurnedFor(NFTRewardDataSource, tier), 5);
        // Check: Reserved left to mint is back to 0
        assertEq(IJB721TiersHook(NFTRewardDataSource).STORE().numberOfPendingReservesFor(NFTRewardDataSource, tier), 0);

        // Build the metadata with the tiers to mint and the overspending flag
        _data[0] = abi.encode(true, rawMetadata);

        // Pass the hook id
        _ids[0] = metadataPayHookId;

        // Generate the metadata
        _hookMetadata = metadataHelper.createMetadata(_ids, _data);

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
            _hookMetadata //_hookMetadata
        );
        // New token balance
        tokenBalance = IERC721(NFTRewardDataSource).balanceOf(_beneficiary);
        // Reserved token available to mint is back at prev value too
        reservedOutstanding =
            IJB721TiersHook(NFTRewardDataSource).STORE().numberOfPendingReservesFor(NFTRewardDataSource, tier);
        // Check: token minted and outstanding reserved balances are correct (+1 as we're rounding up for non-null
        // values)
        assertEq(rawMetadata.length, tokenBalance);
        assertEq(
            reservedOutstanding, (tokenBalance / tiered721DeployerData.tiersconfig.tiers[tier - 1].reserveFrequency) + 1
        );
    }

    // ----- internal helpers ------
    // Create launchProjectFor(..) payload
    function createData()
        internal
        returns (
            JBDeploy721TiersHookConfig memory tiered721DeployerData,
            JBLaunchProjectConfig memory launchProjectConfig
        )
    {
        JB721TierConfig[] memory tierParams = new JB721TierConfig[](10);
        for (uint256 i; i < 10; i++) {
            tierParams[i] = JB721TierConfig({
                price: uint104((i + 1) * 10),
                initialSupply: uint32(10),
                votingUnits: uint32((i + 1) * 10),
                reserveFrequency: 10,
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[i],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: false
            });
        }
        tiered721DeployerData = JBDeploy721TiersHookConfig({
            name: name,
            symbol: symbol,
            rulesets: _jbRulesets,
            baseUri: baseUri,
            tokenUriResolver: IJB721TokenUriResolver(address(0)),
            contractUri: contractUri,
            tiersConfig: JB721InitTiersConfig({tiers: tierParams, currency: 1, decimals: 18, prices: IJBPrices(address(0))}),
            reserveBeneficiary: reserveBeneficiary,
            store: new JB721TiersHookStore(),
            flags: JB721TiersHookFlags({
                preventOverspending: false,
                noNewTiersWithReserves: false,
                noNewTiersWithVotes: false,
                noNewTiersWithOwnerMinting: true
            }),
            governanceType: JB721GovernanceType.NONE
        });
        launchProjectConfig = JBLaunchProjectConfig({
            projectMetadata: _projectMetadata,
            config: _config,
            metadata: _metadata,
            mustStartAtOrAfter: 0,
            splitGroups: _splitGroups,
            fundAccessLimitGroups: _fundAccessLimitGroups,
            terminals: _terminals,
            memo: ""
        });
    }

    // Generate tokenId's based on token number and tier
    function _generateTokenId(uint256 _tierId, uint256 _tokenNumber) internal pure returns (uint256) {
        return (_tierId * 1_000_000_000) + _tokenNumber;
    }
}
