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

    JB721TiersHookProjectDeployer deployer;
    JBAddressRegistry addressRegistry;

    function setUp() public override {
        super.setUp();
        noGovernance = new JB721TiersHook(jbDirectory, jbPermissions);
        JBGoverned721TiersHook onchainGovernance = new JBGoverned721TiersHook(jbDirectory, jbPermissions);
        addressRegistry = new JBAddressRegistry();
        JB721TiersHookDeployer hookDeployer =
            new JB721TiersHookDeployer(onchainGovernance, noGovernance, addressRegistry);
        deployer =
            new JB721TiersHookProjectDeployer(IJBDirectory(jbDirectory), hookDeployer, IJBPermissions(jbPermissions));

        metadataHelper = new MetadataResolverHelper();
    }

    function testDeployLaunchProjectAndAddToRegistry() external {
        (JBDeploy721TiersHookConfig memory tiered721DeployerData, JBLaunchProjectConfig memory launchProjectConfig) =
            createData();
        uint256 projectId =
            deployer.launchProjectFor(projectOwner, tiered721DeployerData, launchProjectConfig, jbController);
        // Check: first project has the id 1?
        assertEq(projectId, 1);
        // Check: hook added to registry?
        address _hook = jbRulesets.currentOf(projectId).dataHook();
        assertEq(addressRegistry.deployerOf(_hook), address(deployer.HOOK_DEPLOYER()));
    }

    function testMintOnPayIfOneTierIsPassed(uint256 valueSent) external {
        valueSent = bound(valueSent, 10, 2000);
        // Highest possible tier is 10
        uint256 highestTier = valueSent <= 100 ? (valueSent / 10) : 10;
        (JBDeploy721TiersHookConfig memory tiered721DeployerData, JBLaunchProjectConfig memory launchProjectConfig) =
            createData();
        uint256 projectId =
            deployer.launchProjectFor(projectOwner, tiered721DeployerData, launchProjectConfig, jbController);
        // Craft the metadata: claim from the highest tier
        uint16[] memory rawMetadata = new uint16[](1);
        rawMetadata[0] = uint16(highestTier);

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(true, rawMetadata);

        address NFTRewardDataHook = jbRulesets.currentOf(projectId).dataHook();

        // Pass the hook id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = bytes4(bytes20(address(NFTRewardDataHook)));

        // Generate the metadata
        bytes memory _hookMetadata = metadataHelper.createMetadata(_ids, _data);

        // Check: correct tier and id?
        vm.expectEmit(true, true, true, true);
        emit Mint(
            _generateTokenId(highestTier, 1),
            highestTier,
            beneficiary,
            valueSent,
            address(jbMultiTerminal) // msg.sender
        );
        vm.prank(caller);
        jbMultiTerminal.pay{value: valueSent}({
            projectId: projectId,
            amount: 100,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: beneficiary,
            minReturnedTokens: 0,
            memo: "Take my money!",
            metadata: _hookMetadata
        });
        uint256 tokenId = _generateTokenId(highestTier, 1);
        // Check: NFT actually received?
        if (valueSent < 10) {
            assertEq(IERC721(NFTRewardDataHook).balanceOf(beneficiary), 0);
        } else {
            assertEq(IERC721(NFTRewardDataHook).balanceOf(beneficiary), 1);
        }
        // Second minted with leftover (if > lowest tier)?
        assertEq(IERC721(NFTRewardDataHook).ownerOf(tokenId), beneficiary);
        assertEq(IJB721TiersHook(NFTRewardDataHook).firstOwnerOf(tokenId), beneficiary);
        // Check: firstOwnerOf and ownerOf are correct after a transfer?
        vm.prank(beneficiary);
        IERC721(NFTRewardDataHook).transferFrom(beneficiary, address(696_969_420), tokenId);
        assertEq(IERC721(NFTRewardDataHook).ownerOf(tokenId), address(696_969_420));
        assertEq(IJB721TiersHook(NFTRewardDataHook).firstOwnerOf(tokenId), beneficiary);
        // Check: same after a second transfer - 0xSTVG-style testing?
        vm.prank(address(696_969_420));
        IERC721(NFTRewardDataHook).transferFrom(address(696_969_420), address(123_456_789), tokenId);
        assertEq(IERC721(NFTRewardDataHook).ownerOf(tokenId), address(123_456_789));
        assertEq(IJB721TiersHook(NFTRewardDataHook).firstOwnerOf(tokenId), beneficiary);
    }

    function testMintOnPayIfMultipleTiersArePassed() external {
        (JBDeploy721TiersHookConfig memory tiered721DeployerData, JBLaunchProjectConfig memory launchProjectConfig) =
            createData();
        uint256 projectId =
            deployer.launchProjectFor(projectOwner, tiered721DeployerData, launchProjectConfig, jbController);
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
                beneficiary,
                _amountNeeded,
                address(jbMultiTerminal) // msg.sender
            );
        }

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(true, rawMetadata);

        address NFTRewardDataHook = jbRulesets.currentOf(projectId).dataHook();

        // Pass the hook id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = bytes4(bytes20(address(NFTRewardDataHook)));

        // Generate the metadata
        bytes memory _hookMetadata = metadataHelper.createMetadata(_ids, _data);

        vm.prank(caller);
        jbMultiTerminal.pay{value: _amountNeeded}({
            projectId: projectId,
            amount: _amountNeeded,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: beneficiary,
            minReturnedTokens: 0,
            memo: "Take my money!",
            metadata: _hookMetadata
        });

        // Check: NFT actually received?
        assertEq(IERC721(NFTRewardDataHook).balanceOf(beneficiary), 5);
        for (uint256 i = 1; i <= 5; i++) {
            uint256 tokenId = _generateTokenId(i, 1);
            assertEq(IJB721TiersHook(NFTRewardDataHook).firstOwnerOf(tokenId), beneficiary);
            // Check: firstOwnerOf and ownerOf are correct after a transfer?
            vm.prank(beneficiary);
            IERC721(NFTRewardDataHook).transferFrom(beneficiary, address(696_969_420), tokenId);
            assertEq(IERC721(NFTRewardDataHook).ownerOf(tokenId), address(696_969_420));
            assertEq(IJB721TiersHook(NFTRewardDataHook).firstOwnerOf(tokenId), beneficiary);
        }
    }

    function testNoMintOnPayWhenNotIncludingTierIds(uint256 valueSent) external {
        valueSent = bound(valueSent, 10, 2000);
        (JBDeploy721TiersHookConfig memory tiered721DeployerData, JBLaunchProjectConfig memory launchProjectConfig) =
            createData();
        uint256 projectId =
            deployer.launchProjectFor(projectOwner, tiered721DeployerData, launchProjectConfig, jbController);
        address NFTRewardDataHook = jbRulesets.currentOf(projectId).dataHook();
        bool _allowOverspending = true;
        uint16[] memory rawMetadata = new uint16[](0);
        bytes memory metadata =
            abi.encode(bytes32(0), bytes32(0), type(IJB721TiersHook).interfaceId, _allowOverspending, rawMetadata);
        vm.prank(caller);
        jbMultiTerminal.pay{value: valueSent}({
            projectId: projectId,
            amount: 100,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: beneficiary,
            minReturnedTokens: 0,
            memo: "Take my money!",
            metadata: metadata
        });
        // Check: No NFT was minted
        assertEq(IERC721(NFTRewardDataHook).balanceOf(beneficiary), 0);
        // Check: User Received the credits
        assertEq(IJB721TiersHook(NFTRewardDataHook).payCreditsOf(beneficiary), valueSent);
    }

    function testNoMintOnPayWhenNotIncludingMetadata(uint256 valueSent) external {
        valueSent = bound(valueSent, 10, 2000);
        (JBDeploy721TiersHookConfig memory tiered721DeployerData, JBLaunchProjectConfig memory launchProjectConfig) =
            createData();
        uint256 projectId =
            deployer.launchProjectFor(projectOwner, tiered721DeployerData, launchProjectConfig, jbController);
        address NFTRewardDataHook = jbRulesets.currentOf(projectId).dataHook();

        vm.prank(caller);
        jbMultiTerminal.pay{value: valueSent}({
            projectId: projectId,
            amount: 100,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: beneficiary,
            minReturnedTokens: 0,
            memo: "Take my money!",
            metadata: new bytes(0)
        });
        // Check: No NFT was minted
        assertEq(IERC721(NFTRewardDataHook).balanceOf(beneficiary), 0);
        // Check: User Received the credits
        assertEq(IJB721TiersHook(NFTRewardDataHook).payCreditsOf(beneficiary), valueSent);
    }

    // TODO This needs care (fuzz fails with insuf reserve for val=10)
    function testMintReservedNft() external {
        uint16 valueSent = 1500;
        uint256 highestTier = valueSent <= 100 ? (valueSent / 10) : 10;
        (JBDeploy721TiersHookConfig memory tiered721DeployerData, JBLaunchProjectConfig memory launchProjectConfig) =
            createData();
        uint256 projectId =
            deployer.launchProjectFor(projectOwner, tiered721DeployerData, launchProjectConfig, jbController);
        address NFTRewardDataHook = jbRulesets.currentOf(projectId).dataHook();
        // Check: 0 reserved token before any mint from a contribution?
        assertEq(
            IJB721TiersHook(NFTRewardDataHook).STORE().numberOfPendingReservesFor(NFTRewardDataHook, highestTier), 0
        );
        // Check: cannot mint 0 reserved token?
        vm.expectRevert(abi.encodeWithSelector(JB721TiersHookStore.INSUFFICIENT_PENDING_RESERVES.selector));
        vm.prank(projectOwner);
        IJB721TiersHook(NFTRewardDataHook).mintPendingReservesFor(highestTier, 1);
        uint16[] memory rawMetadata = new uint16[](1);
        rawMetadata[0] = uint16(highestTier); // reward tier

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(true, rawMetadata);

        // Pass the hook id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = bytes4(bytes20(address(NFTRewardDataHook)));

        // Generate the metadata
        bytes memory _hookMetadata = metadataHelper.createMetadata(_ids, _data);

        // Check: correct tier and id?
        vm.expectEmit(true, true, true, true);
        emit Mint(
            _generateTokenId(highestTier, 1), // First one
            highestTier,
            beneficiary,
            valueSent,
            address(jbMultiTerminal) // msg.sender
        );
        vm.prank(caller);
        jbMultiTerminal.pay{value: valueSent}({
            projectId: projectId,
            amount: 100,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: beneficiary,
            minReturnedTokens: 0,
            memo: "Take my money!",
            metadata: _hookMetadata
        });
        // Check: new reserved one (1 minted == 1 reserved, due to rounding up)
        assertEq(
            IJB721TiersHook(NFTRewardDataHook).STORE().numberOfPendingReservesFor(NFTRewardDataHook, highestTier), 1
        );

        JB721Tier memory _tierBeforeMintingReserves =
            JB721TiersHook(NFTRewardDataHook).STORE().tierOf(NFTRewardDataHook, highestTier, false);

        // Mint the reserved token
        vm.prank(projectOwner);
        IJB721TiersHook(NFTRewardDataHook).mintPendingReservesFor(highestTier, 1);
        // Check: NFT received?
        assertEq(IERC721(NFTRewardDataHook).balanceOf(reserveBeneficiary), 1);

        JB721Tier memory _tierAfterMintingReserves =
            JB721TiersHook(NFTRewardDataHook).STORE().tierOf(NFTRewardDataHook, highestTier, false);
        // the remaining tiers should reduce
        assertLt(_tierAfterMintingReserves.remainingSupply, _tierBeforeMintingReserves.remainingSupply);

        // Check: no more reserved token to mint?
        assertEq(
            IJB721TiersHook(NFTRewardDataHook).STORE().numberOfPendingReservesFor(NFTRewardDataHook, highestTier), 0
        );
        // Check: cannot mint more reserved token?
        vm.expectRevert(abi.encodeWithSelector(JB721TiersHookStore.INSUFFICIENT_PENDING_RESERVES.selector));
        vm.prank(projectOwner);
        IJB721TiersHook(NFTRewardDataHook).mintPendingReservesFor(highestTier, 1);
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
            deployer.launchProjectFor(projectOwner, tiered721DeployerData, launchProjectConfig, jbController);
        // Craft the metadata: claim from the highest tier
        bytes memory _hookMetadata;
        bytes[] memory _data;
        bytes4[] memory _ids;
        address NFTRewardDataHook = jbRulesets.currentOf(projectId).dataHook();
        {
            uint16[] memory rawMetadata = new uint16[](1);
            rawMetadata[0] = uint16(highestTier);

            // Build the metadata with the tiers to mint and the overspending flag
            _data = new bytes[](1);
            _data[0] = abi.encode(true, rawMetadata);

            // Pass the hook id
            _ids = new bytes4[](1);
            _ids[0] = bytes4(bytes20(address(NFTRewardDataHook)));

            // Generate the metadata
            _hookMetadata = metadataHelper.createMetadata(_ids, _data);
        }
        vm.prank(caller);
        jbMultiTerminal.pay{value: valueSent}({
            projectId: projectId,
            amount: 100,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: beneficiary,
            minReturnedTokens: 0,
            memo: "Take my money!",
            metadata: _hookMetadata
        });


        {
            uint256 tokenId = _generateTokenId(highestTier, 1);

            // Craft the metadata: redeem the tokenId
            uint256[] memory redemptionId = new uint256[](1);
            redemptionId[0] = tokenId;

            // Build the metadata with the tiers to redeem
            _data[0] = abi.encode(redemptionId);

            // Pass the hook id
            _ids[0] = bytes4(bytes20(address(NFTRewardDataHook)));

            // Generate the metadata
            _hookMetadata = metadataHelper.createMetadata(_ids, _data);
        }

        // New token balance
        uint256 tokenBalance = IERC721(NFTRewardDataHook).balanceOf(beneficiary);

        vm.prank(beneficiary);
        jbMultiTerminal.redeemTokensOf({
            holder: beneficiary,
            projectId: projectId,
            tokenToReclaim: JBConstants.NATIVE_TOKEN,
            redeemCount: 0,
            minTokensReclaimed: 0,
            beneficiary: payable(beneficiary),
            metadata: _hookMetadata
        });
        // Check: NFT actually redeemed?
        assertEq(IERC721(NFTRewardDataHook).balanceOf(beneficiary), tokenBalance - 1);
        // Check: Burn accounted?
        assertEq(IJB721TiersHook(NFTRewardDataHook).STORE().numberOfBurnedFor(NFTRewardDataHook, highestTier), 1);
        // Calculate if we are rounding up or not. Used to verify 'numberOfPendingReservesFor'
        uint256 _rounding;
        {
            JB721Tier memory _tier =
                IJB721TiersHook(NFTRewardDataHook).STORE().tierOf(NFTRewardDataHook, highestTier, false);
            // '_reserveTokensMinted' is always 0 here
            uint256 _numberOfNonReservesMinted = _tier.initialSupply - _tier.remainingSupply;
            _rounding = _numberOfNonReservesMinted % _tier.reserveFrequency > 0 ? 1 : 0;
        }
        // Check: Reserved left to mint is ?
        assertEq(
            IJB721TiersHook(NFTRewardDataHook).STORE().numberOfPendingReservesFor(NFTRewardDataHook, highestTier),
            (tokenBalance / tiered721DeployerData.tiersConfig.tiers[highestTier - 1].reserveFrequency + _rounding)
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
        uint256 floor = tiered721DeployerData.tiersConfig.tiers[tier - 1].price;
        uint256 projectId =
            deployer.launchProjectFor(projectOwner, tiered721DeployerData, launchProjectConfig, jbController);
        // Craft the metadata: claim 5 from the tier
        uint16[] memory rawMetadata = new uint16[](5);
        for (uint256 i; i < rawMetadata.length; i++) {
            rawMetadata[i] = uint16(tier);
        }

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(true, rawMetadata);

        address NFTRewardDataHook = jbRulesets.currentOf(projectId).dataHook();

        // Pass the hook id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = bytes4(bytes20(address(NFTRewardDataHook)));

        // Generate the metadata
        bytes memory _hookMetadata = metadataHelper.createMetadata(_ids, _data);

        vm.prank(caller);
        jbMultiTerminal.pay{value: floor * rawMetadata.length}({
            projectId: projectId,
            amount: 100,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: beneficiary,
            minReturnedTokens: 0,
            memo: "Take my money!",
            metadata: _hookMetadata
        });

        // New token balance
        uint256 tokenBalance = IERC721(NFTRewardDataHook).balanceOf(beneficiary);
        // Reserved token available to mint
        uint256 reservedOutstanding =
            IJB721TiersHook(NFTRewardDataHook).STORE().numberOfPendingReservesFor(NFTRewardDataHook, tier);
        // Check: token minted and outstanding reserved balances are correct (+1 as we're rounding up for non-null
        // values)
        assertEq(rawMetadata.length, tokenBalance);
        assertEq(
            reservedOutstanding, (tokenBalance / tiered721DeployerData.tiersConfig.tiers[tier - 1].reserveFrequency) + 1
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
        _ids[0] = bytes4(bytes20(address(NFTRewardDataHook)));

        // Generate the metadata
        _hookMetadata = metadataHelper.createMetadata(_ids, _data);

        vm.prank(beneficiary);
        jbMultiTerminal.redeemTokensOf({
            holder: beneficiary,
            projectId: projectId,
            tokenToReclaim: JBConstants.NATIVE_TOKEN,
            redeemCount: 0,
            minTokensReclaimed: 0,
            beneficiary: payable(beneficiary),
            metadata: _hookMetadata
        });
        // Check: NFT actually redeemed?
        assertEq(IERC721(NFTRewardDataHook).balanceOf(beneficiary), 0);
        // Check: Burn accounted?
        assertEq(IJB721TiersHook(NFTRewardDataHook).STORE().numberOfBurnedFor(NFTRewardDataHook, tier), 5);
        // Check: Reserved left to mint is back to 0
        assertEq(IJB721TiersHook(NFTRewardDataHook).STORE().numberOfPendingReservesFor(NFTRewardDataHook, tier), 0);

        // Build the metadata with the tiers to mint and the overspending flag
        _data[0] = abi.encode(true, rawMetadata);

        // Pass the hook id
        _ids[0] = bytes4(bytes20(address(NFTRewardDataHook)));

        // Generate the metadata
        _hookMetadata = metadataHelper.createMetadata(_ids, _data);

        // Check: Can mint again the token previously burned
        vm.prank(caller);
        jbMultiTerminal.pay{value: floor * rawMetadata.length}({
            projectId: projectId,
            amount: 100,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: beneficiary,
            minReturnedTokens: 0,
            memo: "Take my money!",
            metadata: _hookMetadata
        });

        // New token balance
        tokenBalance = IERC721(NFTRewardDataHook).balanceOf(beneficiary);
        // Reserved token available to mint is back at prev value too
        reservedOutstanding =
            IJB721TiersHook(NFTRewardDataHook).STORE().numberOfPendingReservesFor(NFTRewardDataHook, tier);
        // Check: token minted and outstanding reserved balances are correct (+1 as we're rounding up for non-null
        // values)
        assertEq(rawMetadata.length, tokenBalance);
        assertEq(
            reservedOutstanding, (tokenBalance / tiered721DeployerData.tiersConfig.tiers[tier - 1].reserveFrequency) + 1
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
            rulesets: jbRulesets,
            baseUri: baseUri,
            tokenUriResolver: IJB721TokenUriResolver(address(0)),
            contractUri: contractUri,
            tiersConfig: JB721InitTiersConfig({
                tiers: tierParams,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
                decimals: 18,
                prices: IJBPrices(address(0))
            }),
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

        JBPayDataHookRulesetMetadata memory _metadata = JBPayDataHookRulesetMetadata({
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
            useDataHookForRedeem: true,
            metadata: 0x00
        });

        JBPayDataHookRulesetConfig[] memory _rulesetConfigurations = new JBPayDataHookRulesetConfig[](1);
        // Package up the ruleset configuration.
        _rulesetConfigurations[0].mustStartAtOrAfter = 0;
        _rulesetConfigurations[0].duration = 14;
        _rulesetConfigurations[0].weight = 1000 * 10 ** 18;
        _rulesetConfigurations[0].decayRate = 450_000_000;
        _rulesetConfigurations[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfigurations[0].metadata = _metadata;

        JBTerminalConfig[] memory _terminalConfigurations = new JBTerminalConfig[](1);
        address[] memory _tokensToAccept = new address[](1);
        _tokensToAccept[0] = JBConstants.NATIVE_TOKEN;
        _terminalConfigurations[0] = JBTerminalConfig({terminal: jbMultiTerminal, tokensToAccept: _tokensToAccept});

        launchProjectConfig = JBLaunchProjectConfig({
            projectMetadata: projectMetadata,
            rulesetConfigurations: _rulesetConfigurations,
            terminalConfigurations: _terminalConfigurations,
            memo: ""
        });
    }

    // Generate tokenId's based on token number and tier
    function _generateTokenId(uint256 _tierId, uint256 _tokenNumber) internal pure returns (uint256) {
        return (_tierId * 1_000_000_000) + _tokenNumber;
    }
}
