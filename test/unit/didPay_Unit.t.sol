// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../utils/UnitTestSetup.sol";

contract TestJuice721dDelegate_afterPayRecordedWith_Unit is UnitTestSetup {
    using stdStorage for StdStorage;

    function testJBTieredNFTRewardDelegate_afterPayRecordedWith_mintCorrectAmountsAndReserved(
        uint256 _initialSupply,
        uint256 _tokenToMint,
        uint256 _reserveFrequency
    )
        public
    {
        _initialSupply = 400;
        _reserveFrequency = bound(_reserveFrequency, 0, 200);
        _tokenToMint = bound(_tokenToMint, 1, 200);

        defaultTierConfig.initialSupply = uint32(_initialSupply);
        defaultTierConfig.reserveFrequency = uint16(_reserveFrequency);
        ForTest_JB721TiersHook _hook = _initializeForTestHook(1); // 1 tier

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        uint16[] memory _tierIdsToMint = new uint16[](_tokenToMint);

        for (uint256 i; i < _tokenToMint; i++) {
            _tierIdsToMint[i] = uint16(1);
        }

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(false, _tierIdsToMint);

        // Pass the hook id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = bytes4(bytes20(address(_hook)));

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        JBAfterPayRecordedContext memory _payData = JBAfterPayRecordedContext({
            payer: beneficiary,
            projectId: projectId,
            rulesetId: 0,
            amount: JBTokenAmount(
                JBConstants.NATIVE_TOKEN, 10 * _tokenToMint, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))
                ),
            forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                // fwd to hook
            weight: 10 ** 18,
            projectTokenCount: 0,
            beneficiary: beneficiary,
            hookMetadata: bytes(""),
            payerMetadata: _delegateMetadata
        });

        vm.prank(mockTerminalAddress);
        _hook.afterPayRecordedWith(_payData);

        assertEq(_hook.balanceOf(beneficiary), _tokenToMint);

        if (_reserveFrequency > 0 && _initialSupply - _tokenToMint > 0) {
            uint256 _reservedToken = _tokenToMint / _reserveFrequency;
            if (_tokenToMint % _reserveFrequency > 0) _reservedToken += 1;

            assertEq(_hook.STORE().numberOfPendingReservesFor(address(_hook), 1), _reservedToken);

            vm.prank(owner);
            _hook.mintPendingReservesFor(1, _reservedToken);
            assertEq(_hook.balanceOf(reserveBeneficiary), _reservedToken);
        } else {
            assertEq(_hook.balanceOf(reserveBeneficiary), 0);
        }
    }

    // If the amount payed is below the price to receive an NFT the pay should not revert if no metadata passed
    function testJBTieredNFTRewardDelegate_afterPayRecordedWith_doesRevertOnAmountBelowPriceIfNoMetadataIfPreventOverspending(
    )
        public
    {
        JB721TiersHook _hook = _initializeDelegateDefaultTiers(10, true);

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        vm.expectRevert(abi.encodeWithSelector(JB721TiersHook.OVERSPENDING.selector));

        vm.prank(mockTerminalAddress);
        _hook.afterPayRecordedWith(
            JBAfterPayRecordedContext({
                payer: msg.sender,
                projectId: projectId,
                rulesetId: 0,
                amount: JBTokenAmount(
                    JBConstants.NATIVE_TOKEN, tiers[0].price - 1, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))
                    ), // 1 wei below
                    // the
                    // minimum amount
                forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                    // fwd to hook
                weight: 10 ** 18,
                projectTokenCount: 0,
                beneficiary: msg.sender,
                hookMetadata: new bytes(0),
                payerMetadata: new bytes(0)
            })
        );
    }

    // If the amount payed is below the price to receive an NFT the pay should revert if no metadata passed and the
    // allow overspending flag is false.
    function testJBTieredNFTRewardDelegate_afterPayRecordedWith_doesNotRevertOnAmountBelowPriceIfNoMetadata() public {
        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        vm.prank(mockTerminalAddress);
        hook.afterPayRecordedWith(
            JBAfterPayRecordedContext({
                payer: msg.sender,
                projectId: projectId,
                rulesetId: 0,
                amount: JBTokenAmount(
                    JBConstants.NATIVE_TOKEN, tiers[0].price - 1, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))
                    ), // 1 wei below
                    // the
                    // minimum amount
                forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                    // fwd to hook
                weight: 10 ** 18,
                projectTokenCount: 0,
                beneficiary: msg.sender,
                hookMetadata: new bytes(0),
                payerMetadata: new bytes(0)
            })
        );

        assertEq(hook.payCreditsOf(msg.sender), tiers[0].price - 1);
    }

    // If the amount is above contribution floor and a tier is passed, mint as many corresponding tier as possible
    function testJBTieredNFTRewardDelegate_afterPayRecordedWith_mintCorrectTier() public {
        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        uint256 _totalSupplyBeforePay = hook.STORE().totalSupplyOf(address(hook));

        bool _allowOverspending;
        uint16[] memory _tierIdsToMint = new uint16[](3);
        _tierIdsToMint[0] = 1;
        _tierIdsToMint[1] = 1;
        _tierIdsToMint[2] = 2;

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the hook id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = bytes4(bytes20(address(hook)));

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);
        vm.prank(mockTerminalAddress);
        hook.afterPayRecordedWith(
            JBAfterPayRecordedContext({
                payer: msg.sender,
                projectId: projectId,
                rulesetId: 0,
                amount: JBTokenAmount(
                    JBConstants.NATIVE_TOKEN,
                    tiers[0].price * 2 + tiers[1].price,
                    18,
                    uint32(uint160(JBConstants.NATIVE_TOKEN))
                    ),
                forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                    // fwd to hook
                weight: 10 ** 18,
                projectTokenCount: 0,
                beneficiary: msg.sender,
                hookMetadata: new bytes(0),
                payerMetadata: _delegateMetadata
            })
        );

        // Make sure a new NFT was minted
        assertEq(_totalSupplyBeforePay + 3, hook.STORE().totalSupplyOf(address(hook)));

        // Correct tier has been minted?
        assertEq(hook.ownerOf(_generateTokenId(1, 1)), msg.sender);
        assertEq(hook.ownerOf(_generateTokenId(1, 2)), msg.sender);
        assertEq(hook.ownerOf(_generateTokenId(2, 1)), msg.sender);
    }

    function testJBTieredNFTRewardDelegate_afterPayRecordedWith_mintNoneIfNonePassed(uint8 _amount) public {
        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        uint256 _totalSupplyBeforePay = hook.STORE().totalSupplyOf(address(hook));

        bool _allowOverspending = true;
        uint16[] memory _tierIdsToMint = new uint16[](0);
        bytes memory _metadata =
            abi.encode(bytes32(0), bytes32(0), type(IJB721TiersHook).interfaceId, _allowOverspending, _tierIdsToMint);

        vm.prank(mockTerminalAddress);
        hook.afterPayRecordedWith(
            JBAfterPayRecordedContext({
                payer: msg.sender,
                projectId: projectId,
                rulesetId: 0,
                amount: JBTokenAmount(JBConstants.NATIVE_TOKEN, _amount, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))),
                forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                    // fwd to hook
                weight: 10 ** 18,
                projectTokenCount: 0,
                beneficiary: msg.sender,
                hookMetadata: new bytes(0),
                payerMetadata: _metadata
            })
        );

        // Make sure no new NFT was minted if amount >= contribution floor
        assertEq(_totalSupplyBeforePay, hook.STORE().totalSupplyOf(address(hook)));
    }

    function testJBTieredNFTRewardDelegate_afterPayRecordedWith_mintTierAndTrackLeftover() public {
        uint256 _leftover = tiers[0].price - 1;
        uint256 _amount = tiers[0].price + _leftover;

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        bool _allowOverspending = true;
        uint16[] memory _tierIdsToMint = new uint16[](1);
        _tierIdsToMint[0] = uint16(1);

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the hook id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = bytes4(bytes20(address(hook)));

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        // calculating new credits
        uint256 _newCredits = _leftover + hook.payCreditsOf(beneficiary);

        vm.expectEmit(true, true, true, true, address(hook));
        emit AddPayCredits(_newCredits, _newCredits, beneficiary, mockTerminalAddress);

        vm.prank(mockTerminalAddress);
        hook.afterPayRecordedWith(
            JBAfterPayRecordedContext({
                payer: msg.sender,
                projectId: projectId,
                rulesetId: 0,
                amount: JBTokenAmount(JBConstants.NATIVE_TOKEN, _amount, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))),
                forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                    // fwd to hook
                weight: 10 ** 18,
                projectTokenCount: 0,
                beneficiary: beneficiary,
                hookMetadata: new bytes(0),
                payerMetadata: _delegateMetadata
            })
        );

        // Check: credit is updated?
        assertEq(hook.payCreditsOf(beneficiary), _leftover);
    }

    // Mint a given tier with a leftover, mint another given tier then, if the accumulated credit is enough, mint an
    // extra tier
    function testJBTieredNFTRewardDelegate_afterPayRecordedWith_mintCorrectTiersWhenUsingPartialCredits() public {
        uint256 _leftover = tiers[0].price + 1; // + 1 to avoid rounding error
        uint256 _amount = tiers[0].price * 2 + tiers[1].price + _leftover / 2;

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        bool _allowOverspending = true;
        uint16[] memory _tierIdsToMint = new uint16[](3);
        _tierIdsToMint[0] = 1;
        _tierIdsToMint[1] = 1;
        _tierIdsToMint[2] = 2;

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the hook id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = bytes4(bytes20(address(hook)));

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        uint256 _credits = hook.payCreditsOf(beneficiary);

        _leftover = _leftover / 2 + _credits; //left over amount

        vm.expectEmit(true, true, true, true, address(hook));
        emit AddPayCredits(_leftover - _credits, _leftover, beneficiary, mockTerminalAddress);

        // First call will mint the 3 tiers requested + accumulate half of first floor in credit
        vm.prank(mockTerminalAddress);
        hook.afterPayRecordedWith(
            JBAfterPayRecordedContext({
                payer: beneficiary,
                projectId: projectId,
                rulesetId: 0,
                amount: JBTokenAmount(JBConstants.NATIVE_TOKEN, _amount, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))),
                forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                    // fwd to hook
                weight: 10 ** 18,
                projectTokenCount: 0,
                beneficiary: beneficiary,
                hookMetadata: new bytes(0),
                payerMetadata: _delegateMetadata
            })
        );

        uint256 _totalSupplyBefore = hook.STORE().totalSupplyOf(address(hook));
        {
            // We now attempt an additional tier 1 by using the credit we collected from last pay
            uint16[] memory _moreTierIdsToMint = new uint16[](4);
            _moreTierIdsToMint[0] = 1;
            _moreTierIdsToMint[1] = 1;
            _moreTierIdsToMint[2] = 2;
            _moreTierIdsToMint[3] = 1;

            _data[0] = abi.encode(_allowOverspending, _moreTierIdsToMint);

            // Generate the metadata
            _delegateMetadata = metadataHelper.createMetadata(_ids, _data);
        }

        // fetch existing credits
        _credits = hook.payCreditsOf(beneficiary);
        vm.expectEmit(true, true, true, true, address(hook));
        emit UsePayCredits(
            _credits,
            0, // no stashed credits
            beneficiary,
            mockTerminalAddress
        );

        // Second call will mint another 3 tiers requested + mint from the first tier with the credit
        vm.prank(mockTerminalAddress);
        hook.afterPayRecordedWith(
            JBAfterPayRecordedContext({
                payer: beneficiary,
                projectId: projectId,
                rulesetId: 0,
                amount: JBTokenAmount(JBConstants.NATIVE_TOKEN, _amount, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))),
                forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                    // fwd to hook
                weight: 10 ** 18,
                projectTokenCount: 0,
                beneficiary: beneficiary,
                hookMetadata: new bytes(0),
                payerMetadata: _delegateMetadata
            })
        );

        // Check: total supply has increased?
        assertEq(_totalSupplyBefore + 4, hook.STORE().totalSupplyOf(address(hook)));

        // Check: correct tiers have been minted
        // .. On first pay?
        assertEq(hook.ownerOf(_generateTokenId(1, 1)), beneficiary);
        assertEq(hook.ownerOf(_generateTokenId(1, 2)), beneficiary);
        assertEq(hook.ownerOf(_generateTokenId(2, 1)), beneficiary);

        // ... On second pay?
        assertEq(hook.ownerOf(_generateTokenId(1, 3)), beneficiary);
        assertEq(hook.ownerOf(_generateTokenId(1, 4)), beneficiary);
        assertEq(hook.ownerOf(_generateTokenId(1, 5)), beneficiary);
        assertEq(hook.ownerOf(_generateTokenId(2, 2)), beneficiary);

        // Check: no credit is left?
        assertEq(hook.payCreditsOf(beneficiary), 0);
    }

    function testJBTieredNFTRewardDelegate_afterPayRecordedWith_doNotMintWithSomeoneElseCredit() public {
        uint256 _leftover = tiers[0].price + 1; // + 1 to avoid rounding error
        uint256 _amount = tiers[0].price * 2 + tiers[1].price + _leftover / 2;

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        bool _allowOverspending = true;
        uint16[] memory _tierIdsToMint = new uint16[](3);
        _tierIdsToMint[0] = 1;
        _tierIdsToMint[1] = 1;
        _tierIdsToMint[2] = 2;

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the hook id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = bytes4(bytes20(address(hook)));

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        // First call will mint the 3 tiers requested + accumulate half of first floor in credit
        vm.prank(mockTerminalAddress);
        hook.afterPayRecordedWith(
            JBAfterPayRecordedContext({
                payer: beneficiary,
                projectId: projectId,
                rulesetId: 0,
                amount: JBTokenAmount(JBConstants.NATIVE_TOKEN, _amount, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))),
                forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                    // fwd to hook
                weight: 10 ** 18,
                projectTokenCount: 0,
                beneficiary: beneficiary,
                hookMetadata: new bytes(0),
                payerMetadata: _delegateMetadata
            })
        );

        uint256 _totalSupplyBefore = hook.STORE().totalSupplyOf(address(hook));
        uint256 _creditBefore = hook.payCreditsOf(beneficiary);

        // Second call will mint another 3 tiers requested BUT not with the credit accumulated
        vm.prank(mockTerminalAddress);
        hook.afterPayRecordedWith(
            JBAfterPayRecordedContext({
                payer: msg.sender,
                projectId: projectId,
                rulesetId: 0,
                amount: JBTokenAmount(JBConstants.NATIVE_TOKEN, _amount, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))),
                forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                    // fwd to hook
                weight: 10 ** 18,
                projectTokenCount: 0,
                beneficiary: beneficiary,
                hookMetadata: new bytes(0),
                payerMetadata: _delegateMetadata
            })
        );

        // Check: total supply has increased with the 3 token?
        assertEq(_totalSupplyBefore + 3, hook.STORE().totalSupplyOf(address(hook)));

        // Check: correct tiers have been minted
        // .. On first pay?
        assertEq(hook.ownerOf(_generateTokenId(1, 1)), beneficiary);
        assertEq(hook.ownerOf(_generateTokenId(1, 2)), beneficiary);
        assertEq(hook.ownerOf(_generateTokenId(2, 1)), beneficiary);

        // ... On second pay, without extra from the credit?
        assertEq(hook.ownerOf(_generateTokenId(1, 3)), beneficiary);
        assertEq(hook.ownerOf(_generateTokenId(1, 4)), beneficiary);
        assertEq(hook.ownerOf(_generateTokenId(2, 2)), beneficiary);

        // Check: credit is now having both left-overs?
        assertEq(hook.payCreditsOf(beneficiary), _creditBefore * 2);
    }

    // Terminal is in currency 1 with 18 decimal, hook is in currency 2, with 9 decimals
    // The conversion rate is set at 1:2
    function testJBTieredNFTRewardDelegate_afterPayRecordedWith_mintCorrectTierWithAnotherCurrency() public {
        address _jbPrice = address(bytes20(keccak256("MockJBPrice")));
        vm.etch(_jbPrice, new bytes(1));

        // currency 2 with 9 decimals
        JB721TiersHook _hook = _initializeDelegateDefaultTiers(10, false, 2, 9, _jbPrice);

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        // Mock the price oracle call
        uint256 _amountInEth = (tiers[0].price * 2 + tiers[1].price) * 2;
        mockAndExpect(
            _jbPrice,
            abi.encodeCall(IJBPrices.pricePerUnitOf, (projectId, uint32(uint160(JBConstants.NATIVE_TOKEN)), 2, 18)),
            abi.encode(2 * 10 ** 9)
        );

        uint256 _totalSupplyBeforePay = _hook.STORE().totalSupplyOf(address(hook));

        bool _allowOverspending = true;
        uint16[] memory _tierIdsToMint = new uint16[](3);
        _tierIdsToMint[0] = 1;
        _tierIdsToMint[1] = 1;
        _tierIdsToMint[2] = 2;

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the hook id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = bytes4(bytes20(address(_hook)));

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        vm.prank(mockTerminalAddress);
        _hook.afterPayRecordedWith(
            JBAfterPayRecordedContext({
                payer: msg.sender,
                projectId: projectId,
                rulesetId: 0,
                amount: JBTokenAmount(JBConstants.NATIVE_TOKEN, _amountInEth, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))),
                forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                    // fwd to hook
                weight: 10 ** 18,
                projectTokenCount: 0,
                beneficiary: msg.sender,
                hookMetadata: new bytes(0),
                payerMetadata: _delegateMetadata
            })
        );

        // Make sure a new NFT was minted
        assertEq(_totalSupplyBeforePay + 3, _hook.STORE().totalSupplyOf(address(_hook)));

        // Correct tier has been minted?
        assertEq(_hook.ownerOf(_generateTokenId(1, 1)), msg.sender);
        assertEq(_hook.ownerOf(_generateTokenId(1, 2)), msg.sender);
        assertEq(_hook.ownerOf(_generateTokenId(2, 1)), msg.sender);
    }

    // If the tier has been removed, revert
    function testJBTieredNFTRewardDelegate_afterPayRecordedWith_revertIfTierRemoved() public {
        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        uint256 _totalSupplyBeforePay = hook.STORE().totalSupplyOf(address(hook));

        bool _allowOverspending;
        uint16[] memory _tierIdsToMint = new uint16[](3);
        _tierIdsToMint[0] = 1;
        _tierIdsToMint[1] = 1;
        _tierIdsToMint[2] = 2;

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the hook id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = bytes4(bytes20(address(hook)));

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        uint256[] memory _toRemove = new uint256[](1);
        _toRemove[0] = 1;

        vm.prank(owner);
        hook.adjustTiers(new JB721TierConfig[](0), _toRemove);

        vm.expectRevert(abi.encodeWithSelector(JB721TiersHookStore.TIER_REMOVED.selector));

        vm.prank(mockTerminalAddress);
        hook.afterPayRecordedWith(
            JBAfterPayRecordedContext({
                payer: msg.sender,
                projectId: projectId,
                rulesetId: 0,
                amount: JBTokenAmount(
                    JBConstants.NATIVE_TOKEN,
                    tiers[0].price * 2 + tiers[1].price,
                    18,
                    uint32(uint160(JBConstants.NATIVE_TOKEN))
                    ),
                forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                    // fwd to hook
                weight: 10 ** 18,
                projectTokenCount: 0,
                beneficiary: msg.sender,
                hookMetadata: new bytes(0),
                payerMetadata: _delegateMetadata
            })
        );

        // Make sure no new NFT was minted
        assertEq(_totalSupplyBeforePay, hook.STORE().totalSupplyOf(address(hook)));
    }

    function testJBTieredNFTRewardDelegate_afterPayRecordedWith_revertIfNonExistingTier(uint256 _invalidTier) public {
        _invalidTier = bound(_invalidTier, tiers.length + 1, type(uint16).max);

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        uint256 _totalSupplyBeforePay = hook.STORE().totalSupplyOf(address(hook));

        bool _allowOverspending;
        uint16[] memory _tierIdsToMint = new uint16[](1);
        _tierIdsToMint[0] = uint16(_invalidTier);

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the hook id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = bytes4(bytes20(address(hook)));

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        uint256[] memory _toRemove = new uint256[](1);
        _toRemove[0] = 1;

        vm.prank(owner);
        hook.adjustTiers(new JB721TierConfig[](0), _toRemove);

        vm.expectRevert(abi.encodeWithSelector(JB721TiersHookStore.INVALID_TIER.selector));

        vm.prank(mockTerminalAddress);
        hook.afterPayRecordedWith(
            JBAfterPayRecordedContext({
                payer: msg.sender,
                projectId: projectId,
                rulesetId: 0,
                amount: JBTokenAmount(
                    JBConstants.NATIVE_TOKEN,
                    tiers[0].price * 2 + tiers[1].price,
                    18,
                    uint32(uint160(JBConstants.NATIVE_TOKEN))
                    ),
                forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                    // fwd to hook
                weight: 10 ** 18,
                projectTokenCount: 0,
                beneficiary: msg.sender,
                hookMetadata: new bytes(0),
                payerMetadata: _delegateMetadata
            })
        );

        // Make sure no new NFT was minted
        assertEq(_totalSupplyBeforePay, hook.STORE().totalSupplyOf(address(hook)));
    }

    // If the amount is not enought to cover all the tiers requested, revert
    function testJBTieredNFTRewardDelegate_afterPayRecordedWith_revertIfAmountTooLow() public {
        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        uint256 _totalSupplyBeforePay = hook.STORE().totalSupplyOf(address(hook));

        bool _allowOverspending;
        uint16[] memory _tierIdsToMint = new uint16[](3);
        _tierIdsToMint[0] = 1;
        _tierIdsToMint[1] = 1;
        _tierIdsToMint[2] = 2;

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the hook id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = bytes4(bytes20(address(hook)));

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        vm.expectRevert(abi.encodeWithSelector(JB721TiersHookStore.PRICE_EXCEEDS_AMOUNT.selector));

        vm.prank(mockTerminalAddress);
        hook.afterPayRecordedWith(
            JBAfterPayRecordedContext({
                payer: msg.sender,
                projectId: projectId,
                rulesetId: 0,
                amount: JBTokenAmount(
                    JBConstants.NATIVE_TOKEN,
                    tiers[0].price * 2 + tiers[1].price - 1,
                    18,
                    uint32(uint160(JBConstants.NATIVE_TOKEN))
                    ),
                forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                    // fwd to hook
                weight: 10 ** 18,
                projectTokenCount: 0,
                beneficiary: msg.sender,
                hookMetadata: new bytes(0),
                payerMetadata: _delegateMetadata
            })
        );

        // Make sure no new NFT was minted
        assertEq(_totalSupplyBeforePay, hook.STORE().totalSupplyOf(address(hook)));
    }

    function testJBTieredNFTRewardDelegate_afterPayRecordedWith_revertIfAllowanceRunsOutInParticularTier() public {
        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        uint256 _supplyLeft = tiers[0].initialSupply;

        while (true) {
            uint256 _totalSupplyBeforePay = hook.STORE().totalSupplyOf(address(hook));

            bool _allowOverspending = true;

            uint16[] memory tierSelected = new uint16[](1);
            tierSelected[0] = 1;

            // Build the metadata with the tiers to mint and the overspending flag
            bytes[] memory _data = new bytes[](1);
            _data[0] = abi.encode(_allowOverspending, tierSelected);

            // Pass the hook id
            bytes4[] memory _ids = new bytes4[](1);
            _ids[0] = bytes4(bytes20(address(hook)));

            // Generate the metadata
            bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

            // If there is no supply left this should revert
            if (_supplyLeft == 0) {
                vm.expectRevert(abi.encodeWithSelector(JB721TiersHookStore.INSUFFICIENT_SUPPLY_REMAINING.selector));
            }

            // Perform the pay
            vm.prank(mockTerminalAddress);
            hook.afterPayRecordedWith(
                JBAfterPayRecordedContext({
                    payer: msg.sender,
                    projectId: projectId,
                    rulesetId: 0,
                    amount: JBTokenAmount(
                        JBConstants.NATIVE_TOKEN, tiers[0].price, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))
                        ),
                    forwardedAmount: JBTokenAmount(
                        JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))
                        ), // 0 fwd to hook
                    weight: 10 ** 18,
                    projectTokenCount: 0,
                    beneficiary: msg.sender,
                    hookMetadata: new bytes(0),
                    payerMetadata: _delegateMetadata
                })
            );
            // Make sure if there was no supply left there was no NFT minted
            if (_supplyLeft == 0) {
                assertEq(hook.STORE().totalSupplyOf(address(hook)), _totalSupplyBeforePay);
                break;
            } else {
                assertEq(hook.STORE().totalSupplyOf(address(hook)), _totalSupplyBeforePay + 1);
            }
            --_supplyLeft;
        }
    }

    function testJBTieredNFTRewardDelegate_afterPayRecordedWith_revertIfCallerIsNotATerminalOfProjectId(
        address _terminal
    )
        public
    {
        vm.assume(_terminal != mockTerminalAddress);

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, _terminal),
            abi.encode(false)
        );

        // The caller is the _expectedCaller however the terminal in the calldata is not correct
        vm.prank(_terminal);

        vm.expectRevert(abi.encodeWithSelector(JB721Hook.INVALID_PAY_EVENT.selector));

        hook.afterPayRecordedWith(
            JBAfterPayRecordedContext({
                payer: msg.sender,
                projectId: projectId,
                rulesetId: 0,
                amount: JBTokenAmount(address(0), 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))),
                forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                    // fwd to hook
                weight: 10 ** 18,
                projectTokenCount: 0,
                beneficiary: msg.sender,
                hookMetadata: new bytes(0),
                payerMetadata: new bytes(0)
            })
        );
    }

    function testJBTieredNFTRewardDelegate_afterPayRecordedWith_doNotMintIfNotUsingCorrectToken(address token) public {
        vm.assume(token != JBConstants.NATIVE_TOKEN);

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        // The caller is the _expectedCaller however the terminal in the calldata is not correct
        vm.prank(mockTerminalAddress);
        hook.afterPayRecordedWith(
            JBAfterPayRecordedContext({
                payer: msg.sender,
                projectId: projectId,
                rulesetId: 0,
                amount: JBTokenAmount(token, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))),
                forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                    // fwd to hook
                weight: 10 ** 18,
                projectTokenCount: 0,
                beneficiary: msg.sender,
                hookMetadata: new bytes(0),
                payerMetadata: new bytes(0)
            })
        );

        // Check: nothing has been minted
        assertEq(hook.STORE().totalSupplyOf(address(hook)), 0);
    }

    function testJBTieredNFTRewardDelegate_afterPayRecordedWith_mintTiersWhenUsingExistingCredits_when_existing_credits_more_than_new_credits(
    )
        public
    {
        uint256 _leftover = tiers[0].price + 1; // + 1 to avoid rounding error
        uint256 _amount = tiers[0].price * 2 + tiers[1].price + _leftover / 2;

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        bool _allowOverspending = true;
        uint16[] memory _tierIdsToMint = new uint16[](3);
        _tierIdsToMint[0] = 1;
        _tierIdsToMint[1] = 1;
        _tierIdsToMint[2] = 2;

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the hook id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = bytes4(bytes20(address(hook)));

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        uint256 _credits = hook.payCreditsOf(beneficiary);
        _leftover = _leftover / 2 + _credits; //left over amount

        vm.expectEmit(true, true, true, true, address(hook));
        emit AddPayCredits(_leftover - _credits, _leftover, beneficiary, mockTerminalAddress);

        // First call will mint the 3 tiers requested + accumulate half of first floor in credit
        vm.prank(mockTerminalAddress);
        hook.afterPayRecordedWith(
            JBAfterPayRecordedContext({
                payer: beneficiary,
                projectId: projectId,
                rulesetId: 0,
                amount: JBTokenAmount(JBConstants.NATIVE_TOKEN, _amount, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))),
                forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                    // fwd to hook
                weight: 10 ** 18,
                projectTokenCount: 0,
                beneficiary: beneficiary,
                hookMetadata: new bytes(0),
                payerMetadata: _delegateMetadata
            })
        );

        uint256 _totalSupplyBefore = hook.STORE().totalSupplyOf(address(hook));
        {
            // We now attempt an additional tier 1 by using the credit we collected from last pay
            uint16[] memory _moreTierIdsToMint = new uint16[](1);
            _moreTierIdsToMint[0] = 1;

            _data[0] = abi.encode(_allowOverspending, _moreTierIdsToMint);

            // Generate the metadata
            _delegateMetadata = metadataHelper.createMetadata(_ids, _data);
        }

        // fetch existing credits
        _credits = hook.payCreditsOf(beneficiary);

        // using existing credits to mint
        _leftover = tiers[0].price - 1 - _credits;
        vm.expectEmit(true, true, true, true, address(hook));
        emit UsePayCredits(_credits - _leftover, _leftover, beneficiary, mockTerminalAddress);

        // minting with left over credits
        vm.prank(mockTerminalAddress);
        hook.afterPayRecordedWith(
            JBAfterPayRecordedContext({
                payer: beneficiary,
                projectId: projectId,
                rulesetId: 0,
                amount: JBTokenAmount(
                    JBConstants.NATIVE_TOKEN, tiers[0].price - 1, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))
                    ),
                forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                    // fwd to hook
                weight: 10 ** 18,
                projectTokenCount: 0,
                beneficiary: beneficiary,
                hookMetadata: new bytes(0),
                payerMetadata: _delegateMetadata
            })
        );

        // total supply increases
        assertEq(_totalSupplyBefore + 1, hook.STORE().totalSupplyOf(address(hook)));
    }

    function testJBTieredNFTRewardDelegate_afterPayRecordedWith_revertIfUnexpectedLeftover() public {
        uint256 _leftover = tiers[1].price - 1;
        uint256 _amount = tiers[0].price + _leftover;

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );
        bool _allowOverspending;
        uint16[] memory _tierIdsToMint = new uint16[](0);

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the hook id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = bytes4(bytes20(address(hook)));

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);
        vm.prank(mockTerminalAddress);
        vm.expectRevert(abi.encodeWithSelector(JB721TiersHook.OVERSPENDING.selector));
        hook.afterPayRecordedWith(
            JBAfterPayRecordedContext({
                payer: msg.sender,
                projectId: projectId,
                rulesetId: 0,
                amount: JBTokenAmount(JBConstants.NATIVE_TOKEN, _amount, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))),
                forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                    // fwd to hook
                weight: 10 ** 18,
                projectTokenCount: 0,
                beneficiary: beneficiary,
                hookMetadata: new bytes(0),
                payerMetadata: _delegateMetadata
            })
        );
    }

    function testJBTieredNFTRewardDelegate_afterPayRecordedWith_revertIfUnexpectedLeftoverAndPrevented(bool _prevent)
        public
    {
        uint256 _leftover = tiers[1].price - 1;
        uint256 _amount = tiers[0].price + _leftover;

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        // Get the currently selected flags
        JB721TiersHookFlags memory flags = hook.STORE().flagsOf(address(hook));

        // Modify the prevent
        flags.preventOverspending = _prevent;

        // Mock the call to return the new flags
        mockAndExpect(
            address(hook.STORE()),
            abi.encodeWithSelector(IJB721TiersHookStore.flagsOf.selector, address(hook)),
            abi.encode(flags)
        );

        bool _allowOverspending = true;
        uint16[] memory _tierIdsToMint = new uint16[](0);

        bytes memory _metadata =
            abi.encode(bytes32(0), bytes32(0), type(IJB721TiersHook).interfaceId, _allowOverspending, _tierIdsToMint);

        // If prevent is enabled the call should revert, otherwise we should receive credits
        if (_prevent) {
            vm.expectRevert(abi.encodeWithSelector(JB721TiersHook.OVERSPENDING.selector));
        } else {
            uint256 _credits = hook.payCreditsOf(beneficiary);
            uint256 _stashedCredits = _credits;
            // calculating new credits since _leftover is non zero
            uint256 _newCredits = tiers[0].price + _leftover + _stashedCredits;
            vm.expectEmit(true, true, true, true, address(hook));
            emit AddPayCredits(_newCredits - _credits, _newCredits, beneficiary, mockTerminalAddress);
        }
        vm.prank(mockTerminalAddress);
        hook.afterPayRecordedWith(
            JBAfterPayRecordedContext({
                payer: msg.sender,
                projectId: projectId,
                rulesetId: 0,
                amount: JBTokenAmount(JBConstants.NATIVE_TOKEN, _amount, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))),
                forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                    // fwd to hook
                weight: 10 ** 18,
                projectTokenCount: 0,
                beneficiary: beneficiary,
                hookMetadata: new bytes(0),
                payerMetadata: _metadata
            })
        );
    }

    // Mint are still possible, transfer to other addresses than 0 (ie burn) are reverting (if hook flag pausable is
    // true)
    function testJBTieredNFTRewardDelegate_beforeTransferHook_revertTransferIfTransferPausedInFundingCycle() public {
        defaultTierConfig.transfersPausable = true;
        JB721TiersHook _hook = _initializeDelegateDefaultTiers(10);

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

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
                            dataHook: address(_hook),
                            metadata: 1 // 001_2
                        })
                        )
                })
            )
        );

        bool _allowOverspending;
        uint16[] memory _tierIdsToMint = new uint16[](3);
        _tierIdsToMint[0] = 1;
        _tierIdsToMint[1] = 1;
        _tierIdsToMint[2] = 2;

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the hook id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = bytes4(bytes20(address(_hook)));

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        vm.prank(mockTerminalAddress);
        _hook.afterPayRecordedWith(
            JBAfterPayRecordedContext({
                payer: msg.sender,
                projectId: projectId,
                rulesetId: 0,
                amount: JBTokenAmount(
                    JBConstants.NATIVE_TOKEN,
                    tiers[0].price * 2 + tiers[1].price,
                    18,
                    uint32(uint160(JBConstants.NATIVE_TOKEN))
                    ),
                forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                    // fwd to hook
                weight: 10 ** 18,
                projectTokenCount: 0,
                beneficiary: msg.sender,
                hookMetadata: new bytes(0),
                payerMetadata: _delegateMetadata
            })
        );

        uint256 _tokenId = _generateTokenId(1, 1);

        vm.expectRevert(JB721TiersHook.TIER_TRANSFERS_PAUSED.selector);

        vm.prank(msg.sender);
        IERC721(_hook).transferFrom(msg.sender, beneficiary, _tokenId);
    }

    // If FC has the pause transfer flag but the hook flag 'pausable' is false, transfer are not paused
    // (this bypasses the call to the FC store)
    function testJBTieredNFTRewardDelegate_beforeTransferHook_pauseFlagOverrideFundingCycleTransferPaused() public {
        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        JB721TiersHook _hook = _initializeDelegateDefaultTiers(10);

        bool _allowOverspending;
        uint16[] memory _tierIdsToMint = new uint16[](3);
        _tierIdsToMint[0] = 1;
        _tierIdsToMint[1] = 1;
        _tierIdsToMint[2] = 2;

        // Build the metadata with the tiers to mint and the overspending flag
        bytes[] memory _data = new bytes[](1);
        _data[0] = abi.encode(_allowOverspending, _tierIdsToMint);

        // Pass the hook id
        bytes4[] memory _ids = new bytes4[](1);
        _ids[0] = bytes4(bytes20(address(_hook)));

        // Generate the metadata
        bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        vm.prank(mockTerminalAddress);
        _hook.afterPayRecordedWith(
            JBAfterPayRecordedContext({
                payer: msg.sender,
                projectId: projectId,
                rulesetId: 0,
                amount: JBTokenAmount(
                    JBConstants.NATIVE_TOKEN,
                    tiers[0].price * 2 + tiers[1].price,
                    18,
                    uint32(uint160(JBConstants.NATIVE_TOKEN))
                    ),
                forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                    // fwd to hook
                weight: 10 ** 18,
                projectTokenCount: 0,
                beneficiary: msg.sender,
                hookMetadata: new bytes(0),
                payerMetadata: _delegateMetadata
            })
        );

        uint256 _tokenId = _generateTokenId(1, 1);
        vm.prank(msg.sender);
        IERC721(_hook).transferFrom(msg.sender, beneficiary, _tokenId);
        // Check: token transferred
        assertEq(IERC721(_hook).ownerOf(_tokenId), beneficiary);
    }

    // This bypasses the call to FC store
    function testJBTieredNFTRewardDelegate_beforeTransferHook_redeemEvenIfTransferPausedInFundingCycle() public {
        address _holder = address(bytes20(keccak256("_holder")));

        JB721TiersHook _hook = _initializeDelegateDefaultTiers(10);

        // Mock the directory call
        mockAndExpect(
            address(mockJBDirectory),
            abi.encodeWithSelector(IJBDirectory.isTerminalOf.selector, projectId, mockTerminalAddress),
            abi.encode(true)
        );

        // Metadata to mint
        bytes memory _delegateMetadata;
        bytes[] memory _data = new bytes[](1);
        bytes4[] memory _ids = new bytes4[](1);

        {
            // Craft the metadata: mint the specified tier
            uint16[] memory rawMetadata = new uint16[](1);
            rawMetadata[0] = uint16(1); // 1 indexed

            // Build the metadata with the tiers to mint and the overspending flag
            _data[0] = abi.encode(true, rawMetadata);

            // Pass the hook id
            _ids[0] = bytes4(bytes20(address(_hook)));

            // Generate the metadata
            _delegateMetadata = metadataHelper.createMetadata(_ids, _data);
        }

        // We mint the NFTs otherwise the voting balance does not get incremented
        // which leads to underflow on redeem
        vm.prank(mockTerminalAddress);
        _hook.afterPayRecordedWith(
            JBAfterPayRecordedContext({
                payer: _holder,
                projectId: projectId,
                rulesetId: 0,
                amount: JBTokenAmount(
                    JBConstants.NATIVE_TOKEN, tiers[0].price, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))
                    ),
                forwardedAmount: JBTokenAmount(JBConstants.NATIVE_TOKEN, 0, 18, uint32(uint160(JBConstants.NATIVE_TOKEN))), // 0
                    // fwd to hook
                weight: 10 ** 18,
                projectTokenCount: 0,
                beneficiary: _holder,
                hookMetadata: new bytes(0),
                payerMetadata: _delegateMetadata
            })
        );

        uint256[] memory _tokenToRedeem = new uint256[](1);
        _tokenToRedeem[0] = _generateTokenId(1, 1);

        // Build the metadata with the tiers to redeem
        _data[0] = abi.encode(_tokenToRedeem);

        // Pass the hook id
        _ids[0] = bytes4(bytes20(address(_hook)));

        // Generate the metadata
        _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

        vm.prank(mockTerminalAddress);
        _hook.afterRedeemRecordedWith(
            JBAfterRedeemRecordedContext({
                holder: _holder,
                projectId: projectId,
                rulesetId: 1,
                redeemCount: 0,
                reclaimedAmount: JBTokenAmount({
                    token: address(0),
                    value: 0,
                    decimals: 18,
                    currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
                }),
                forwardedAmount: JBTokenAmount({
                    token: address(0),
                    value: 0,
                    decimals: 18,
                    currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
                }), // 0
                redemptionRate: 5000,
                // fwd to hook
                beneficiary: payable(_holder),
                hookMetadata: bytes(""),
                redeemerMetadata: _delegateMetadata
            })
        );

        // Balance should be 0 again
        assertEq(_hook.balanceOf(_holder), 0);
    }
}
