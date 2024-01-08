pragma solidity 0.8.23;

import "../utils/UnitTestSetup.sol";

contract TestJuice721dDelegate_mintFor_mintReservesFor_Unit is UnitTestSetup {
    using stdStorage for StdStorage;

    function testJBTieredNFTRewardDelegate_mintReservesFor_MintReservedNft() public {
        // 120 are minted, 1 out of these is reserved, meaning 119 non-reserved are minted. The reserveFrequency is 40%
        // (4000/10000)
        // meaning there are 47 total reserved to mint, 1 being already minted, 46 are outstanding
        uint256 initialSupply = 200;
        uint256 totalMinted = 120;
        uint256 reservedMinted = 1;
        uint256 reserveFrequency = 4000;
        uint256 nbTiers = 3;

        ForTest_JB721TiersHook _hook = _initializeForTestHook(nbTiers);

        for (uint256 i; i < nbTiers; i++) {
            _hook.test_store().ForTest_setTier(
                address(_hook),
                i + 1,
                JBStored721Tier({
                    price: uint104((i + 1) * 10),
                    remainingSupply: uint32(initialSupply - totalMinted),
                    initialSupply: uint32(initialSupply),
                    votingUnits: uint16(0),
                    reserveFrequency: uint16(reserveFrequency),
                    category: uint24(100),
                    packedBools: _hook.test_store().ForTest_packBools(false, false, true)
                })
            );
            _hook.test_store().ForTest_setReservesMintedFor(address(_hook), i + 1, reservedMinted);
        }

        for (uint256 tier = 1; tier <= nbTiers; tier++) {
            uint256 mintable = _hook.test_store().numberOfPendingReservesFor(address(_hook), tier);

            for (uint256 token = 1; token <= mintable; token++) {
                vm.expectEmit(true, true, true, true, address(_hook));
                emit MintReservedNft(_generateTokenId(tier, totalMinted + token), tier, reserveBeneficiary, owner);
            }

            vm.prank(owner);
            _hook.mintPendingReservesFor(tier, mintable);

            // Check balance
            assertEq(_hook.balanceOf(reserveBeneficiary), mintable * tier);
        }
    }

    function testJBTieredNFTRewardDelegate_mintReservesFor_mintMultipleReservedToken() public {
        // 120 are minted, 1 out of these is reserved, meaning 119 non-reserved are minted. The reserveFrequency is 40%
        // (4000/10000)
        // meaning there are 47 total reserved to mint, 1 being already minted, 46 are outstanding
        uint256 initialSupply = 200;
        uint256 totalMinted = 120;
        uint256 reservedMinted = 1;
        uint256 reserveFrequency = 4000;
        uint256 nbTiers = 3;

        ForTest_JB721TiersHook _hook = _initializeForTestHook(nbTiers);

        for (uint256 i; i < nbTiers; i++) {
            _hook.test_store().ForTest_setTier(
                address(_hook),
                i + 1,
                JBStored721Tier({
                    price: uint104((i + 1) * 10),
                    remainingSupply: uint32(initialSupply - totalMinted),
                    initialSupply: uint32(initialSupply),
                    votingUnits: uint16(0),
                    reserveFrequency: uint16(reserveFrequency),
                    category: uint24(100),
                    packedBools: _hook.test_store().ForTest_packBools(false, false, true)
                })
            );
            _hook.test_store().ForTest_setReservesMintedFor(address(_hook), i + 1, reservedMinted);
        }

        uint256 _totalMintable; // Keep a running counter

        JB721TiersMintReservesParams[] memory _reservedToMint = new JB721TiersMintReservesParams[](nbTiers);

        for (uint256 tier = 1; tier <= nbTiers; tier++) {
            uint256 mintable = _hook.test_store().numberOfPendingReservesFor(address(_hook), tier);
            _reservedToMint[tier - 1] = JB721TiersMintReservesParams({tierId: tier, count: mintable});
            _totalMintable += mintable;
            for (uint256 token = 1; token <= mintable; token++) {
                uint256 _tokenNonce = totalMinted + token; // Avoid stack too deep
                vm.expectEmit(true, true, true, true, address(_hook));
                emit MintReservedNft(_generateTokenId(tier, _tokenNonce), tier, reserveBeneficiary, owner);
            }
        }

        vm.prank(owner);
        _hook.mintPendingReservesFor(_reservedToMint);

        // Check balance
        assertEq(_hook.balanceOf(reserveBeneficiary), _totalMintable);
    }

    function testJBTieredNFTRewardDelegate_mintReservesFor_revertIfReservedMintingIsPausedInFundingCycle() public {
        // 120 are minted, 1 out of these is reserved, meaning 119 non-reserved are minted. The reserveFrequency is 40%
        // (4000/10000)
        // meaning there are 47 total reserved to mint, 1 being already minted, 46 are outstanding
        uint256 initialSupply = 200;
        uint256 totalMinted = 120;
        uint256 reservedMinted = 1;
        uint256 reserveFrequency = 4000;
        uint256 nbTiers = 3;

        mockAndExpect(
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
                            metadata: 2 // == 010_2
                        })
                        )
                })
            )
        );

        ForTest_JB721TiersHook _hook = _initializeForTestHook(nbTiers);

        for (uint256 i; i < nbTiers; i++) {
            _hook.test_store().ForTest_setTier(
                address(_hook),
                i + 1,
                JBStored721Tier({
                    price: uint104((i + 1) * 10),
                    remainingSupply: uint32(initialSupply - totalMinted),
                    initialSupply: uint32(initialSupply),
                    votingUnits: uint16(0),
                    reserveFrequency: uint16(reserveFrequency),
                    category: uint24(100),
                    packedBools: _hook.test_store().ForTest_packBools(false, false, true)
                })
            );
            _hook.test_store().ForTest_setReservesMintedFor(address(_hook), i + 1, reservedMinted);
        }

        for (uint256 tier = 1; tier <= nbTiers; tier++) {
            uint256 mintable = _hook.test_store().numberOfPendingReservesFor(address(_hook), tier);
            vm.prank(owner);
            vm.expectRevert(JB721TiersHook.MINT_RESERVE_NFTS_PAUSED.selector);
            _hook.mintPendingReservesFor(tier, mintable);
        }
    }

    function testJBTieredNFTRewardHook_mintReservesFor_revertIfNotEnoughReservedLeft() public {
        uint256 initialSupply = 200;
        uint256 totalMinted = 120;
        uint256 reservedMinted = 1;
        uint256 reserveFrequency = 4000;

        ForTest_JB721TiersHook _hook = _initializeForTestHook(10);

        for (uint256 i; i < 10; i++) {
            _hook.test_store().ForTest_setTier(
                address(_hook),
                i + 1,
                JBStored721Tier({
                    price: uint104((i + 1) * 10),
                    remainingSupply: uint32(initialSupply - totalMinted),
                    initialSupply: uint32(initialSupply),
                    votingUnits: uint16(0),
                    reserveFrequency: uint16(reserveFrequency),
                    category: uint24(100),
                    packedBools: _hook.test_store().ForTest_packBools(false, false, true)
                })
            );
            _hook.test_store().ForTest_setReservesMintedFor(address(_hook), i + 1, reservedMinted);
        }

        for (uint256 i = 1; i <= 10; i++) {
            // Get the amount that we can mint successfully
            uint256 amount = _hook.test_store().numberOfPendingReservesFor(address(_hook), i);
            // Increase it by 1 to cause an error
            amount++;
            vm.expectRevert(abi.encodeWithSelector(JB721TiersHookStore.INSUFFICIENT_PENDING_RESERVES.selector));
            vm.prank(owner);
            _hook.mintPendingReservesFor(i, amount);
        }
    }

    function testJBTieredNFTRewardHook_use_default_reserved_tokenbeneficiary() public {
        uint256 initialSupply = 200;
        uint256 totalMinted = 120;
        uint256 reserveFrequency = 9;

        ForTest_JB721TiersHook _hook = _initializeForTestHook(10);

        for (uint256 i; i < 10; i++) {
            _hook.test_store().ForTest_setTier(
                address(_hook),
                i + 1,
                JBStored721Tier({
                    price: uint104((i + 1) * 10),
                    remainingSupply: uint32(initialSupply - totalMinted),
                    initialSupply: uint32(initialSupply),
                    votingUnits: uint16(0),
                    reserveFrequency: uint16(reserveFrequency),
                    category: uint24(100),
                    packedBools: _hook.test_store().ForTest_packBools(false, false, true)
                })
            );
        }
    }

    function testJBTieredNFTRewardDelegate_no_reserved_rate_if_nobeneficiary_set() public {
        uint256 initialSupply = 200;
        uint256 totalMinted = 120;
        uint256 reservedMinted = 10;
        uint256 reserveFrequency = 9;

        reserveBeneficiary = address(0);
        ForTest_JB721TiersHook _hook = _initializeForTestHook(10);

        for (uint256 i; i < 10; i++) {
            _hook.test_store().ForTest_setTier(
                address(_hook),
                i + 1,
                JBStored721Tier({
                    price: uint104((i + 1) * 10),
                    remainingSupply: uint32(initialSupply - totalMinted),
                    initialSupply: uint32(initialSupply),
                    votingUnits: uint16(0),
                    reserveFrequency: uint16(reserveFrequency),
                    category: uint24(100),
                    packedBools: _hook.test_store().ForTest_packBools(false, false, true)
                })
            );
            _hook.test_store().ForTest_setReservesMintedFor(address(_hook), i + 1, reservedMinted);
        }

        // fetching existing tiers
        JB721Tier[] memory _storedTiers = _hook.test_store().tiersOf(address(_hook), new uint256[](0), false, 0, 10);

        // making sure reserved rate is 0
        for (uint256 i; i < 10; i++) {
            assertEq(_storedTiers[i].reserveFrequency, 0, "wrong reserved rate");
        }
        for (uint256 i; i < 10; i++) {
            assertEq(
                _hook.test_store().numberOfPendingReservesFor(address(_hook), i + 1),
                0,
                "wrong outstanding reserved tokens"
            );
        }
    }

    function testJBTieredNFTRewardDelegate_mintFor_mintArrayOfTiers() public {
        uint256 nbTiers = 3;

        defaultTierConfig.allowOwnerMint = true;
        defaultTierConfig.reserveFrequency = 0;
        ForTest_JB721TiersHook _hook = _initializeForTestHook(nbTiers);

        uint16[] memory _tiersToMint = new uint16[](nbTiers * 2);
        for (uint256 i; i < nbTiers; i++) {
            _tiersToMint[i] = uint16(i) + 1;
            _tiersToMint[_tiersToMint.length - 1 - i] = uint16(i) + 1;
        }

        vm.prank(owner);
        _hook.mintFor(_tiersToMint, beneficiary);

        assertEq(_hook.balanceOf(beneficiary), 6);
        assertEq(_hook.ownerOf(_generateTokenId(1, 1)), beneficiary);
        assertEq(_hook.ownerOf(_generateTokenId(1, 2)), beneficiary);
        assertEq(_hook.ownerOf(_generateTokenId(2, 1)), beneficiary);
        assertEq(_hook.ownerOf(_generateTokenId(2, 2)), beneficiary);
        assertEq(_hook.ownerOf(_generateTokenId(3, 1)), beneficiary);
        assertEq(_hook.ownerOf(_generateTokenId(3, 2)), beneficiary);
    }

    function testJBTieredNFTRewardDelegate_mintFor_revertIfManualMintNotAllowed() public {
        uint256 nbTiers = 10;

        uint16[] memory _tiersToMint = new uint16[](nbTiers * 2);
        for (uint256 i; i < nbTiers; i++) {
            _tiersToMint[i] = uint16(i) + 1;
            _tiersToMint[_tiersToMint.length - 1 - i] = uint16(i) + 1;
        }

        defaultTierConfig.allowOwnerMint = false;
        ForTest_JB721TiersHook _hook = _initializeForTestHook(nbTiers);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(JB721TiersHookStore.CANT_MINT_MANUALLY.selector));
        _hook.mintFor(_tiersToMint, beneficiary);
    }
}
