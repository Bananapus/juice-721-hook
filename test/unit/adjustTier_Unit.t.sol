pragma solidity 0.8.23;

import "../utils/UnitTestSetup.sol";

contract TestJuice721dDelegate_adjustTier_Unit is UnitTestSetup {
    using stdStorage for StdStorage;

    function testJBTieredNFTRewardDelegate_tiers_adjustTier_remove_tiers_multiple_times(
        uint256 initialNumberOfTiers,
        uint256 numberOfFloorTiersToAdd,
        uint256 seed
    )
        public
    {
        // Include adding X new tiers when 0 preexisting ones
        initialNumberOfTiers = bound(initialNumberOfTiers, 0, 10);

        numberOfFloorTiersToAdd = bound(numberOfFloorTiersToAdd, 4, 14);
        uint16[] memory floorTiersToAdd = _createArray(numberOfFloorTiersToAdd, seed);

        // Floor are sorted in ascending orderen
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        // Initialize first tiers to add
        JB721TiersHook _hook = _initializeDelegateDefaultTiers(initialNumberOfTiers);

        // Create new tiers to add
        (JB721TierConfig[] memory _tiersParams,) =
            _createTiers(defaultTierConfig, numberOfFloorTiersToAdd, initialNumberOfTiers, floorTiersToAdd);

        // remove 2 tiers and add the new ones
        uint256 _tiersLeft = initialNumberOfTiers;

        _tiersLeft = _addDeleteTiers(_hook, _tiersLeft, 2, _tiersParams);

        // remove another 2 tiers but don't add any new ones
        _addDeleteTiers(_hook, _tiersLeft, 2, new JB721TierConfig[](0));

        // Fecth max 100 tiers (will downsize)
        JB721Tier[] memory _storedTiers = _hook.STORE().tiersOf(address(_hook), new uint256[](0), false, 0, 100);
        // if the tiers have same category then the the tiers added last will have a lower index in the array
        // else the tiers would be sorted by categories
        for (uint256 i = 1; i < _storedTiers.length; i++) {
            if (_storedTiers[i - 1].category == _storedTiers[i].category) {
                assertGt(_storedTiers[i - 1].id, _storedTiers[i].id, "Sorting error if same cat");
            } else {
                assertLt(_storedTiers[i - 1].category, _storedTiers[i].category, "Sorting error if diff cat");
            }
        }
    }

    function testJBTieredNFTRewardDelegate_tiers_added_recently_fetched_first_sorted_category_wise_after_tiers_have_been_cleaned(
        uint256 initialNumberOfTiers,
        uint256 numberOfFloorTiersToAdd,
        uint256 seed
    )
        public
    {
        initialNumberOfTiers = bound(initialNumberOfTiers, 3, 14);
        numberOfFloorTiersToAdd = bound(numberOfFloorTiersToAdd, 1, 15);
        uint16[] memory floorTiersToAdd = _createArray(numberOfFloorTiersToAdd, seed);

        // Floor are sorted in ascending orderen
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        JB721TiersHook _hook = _initializeDelegateDefaultTiers(initialNumberOfTiers);

        // Create new tiers to add
        uint256 _currentNumberOfTiers = initialNumberOfTiers;

        (JB721TierConfig[] memory _tiersParamsToAdd,) =
            _createTiers(defaultTierConfig, numberOfFloorTiersToAdd, initialNumberOfTiers, floorTiersToAdd);

        _currentNumberOfTiers = _addDeleteTiers(_hook, _currentNumberOfTiers, 0, _tiersParamsToAdd);
        _currentNumberOfTiers = _addDeleteTiers(_hook, _currentNumberOfTiers, 2, _tiersParamsToAdd);

        JB721Tier[] memory _storedTiers = _hook.STORE().tiersOf(address(_hook), new uint256[](0), false, 0, 100);

        assertEq(_storedTiers.length, _currentNumberOfTiers, "Length mismatch");
        // if the tiers have same category then the the tiers added last will have a lower index in the array
        // else the tiers would be sorted by categories
        for (uint256 i = 1; i < _storedTiers.length; i++) {
            if (_storedTiers[i - 1].category == _storedTiers[i].category) {
                assertGt(_storedTiers[i - 1].id, _storedTiers[i].id, "Sorting error if same cat");
            } else {
                assertLt(_storedTiers[i - 1].category, _storedTiers[i].category, "Sorting error if diff cat");
            }
        }
    }

    function testJBTieredNFTRewardDelegate_tiers_added_recently_fetched_first_sorted_category_wise(
        uint256 initialNumberOfTiers,
        uint256 numberOfFloorTiersToAdd,
        uint256 seed
    )
        public
    {
        // Include adding X new tiers when 0 preexisting ones
        initialNumberOfTiers = bound(initialNumberOfTiers, 0, 10);

        numberOfFloorTiersToAdd = bound(numberOfFloorTiersToAdd, 4, 14);
        uint16[] memory floorTiersToAdd = _createArray(numberOfFloorTiersToAdd, seed);

        // Floor are sorted in ascending orderen
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        // Initialize first tiers to add
        JB721TiersHook _hook = _initializeDelegateDefaultTiers(initialNumberOfTiers);

        // Create new tiers to add
        (JB721TierConfig[] memory _tiersParams,) =
            _createTiers(defaultTierConfig, numberOfFloorTiersToAdd, initialNumberOfTiers, floorTiersToAdd);

        // remove 2 tiers and add the new ones
        uint256 _tiersLeft = initialNumberOfTiers;

        _tiersLeft = _addDeleteTiers(_hook, _tiersLeft, 0, _tiersParams);

        JB721Tier[] memory _storedTiers = _hook.STORE().tiersOf(address(_hook), new uint256[](0), false, 0, 100);
        // if the tiers have same category then the the tiers added last will have a lower index in the array
        // else the tiers would be sorted by categories
        for (uint256 i = 1; i < _storedTiers.length; i++) {
            if (_storedTiers[i - 1].category == _storedTiers[i].category) {
                assertGt(_storedTiers[i - 1].id, _storedTiers[i].id, "Sorting error if same cat");
            } else {
                assertLt(_storedTiers[i - 1].category, _storedTiers[i].category, "Sorting error if diff cat");
            }
        }
    }

    function testJBTieredNFTRewardDelegate_adjustTiers_addNewTiers_With_Non_Sequential_Categories(
        uint256 initialNumberOfTiers,
        uint256 numberOfFloorTiersToAdd,
        uint256 seed
    )
        public
    {
        initialNumberOfTiers = bound(initialNumberOfTiers, 2, 10);

        numberOfFloorTiersToAdd = bound(numberOfFloorTiersToAdd, 4, 14);
        uint16[] memory floorTiersToAdd = _createArray(numberOfFloorTiersToAdd, seed);

        // Floor are sorted in ascending orderen
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        // Initialize first tiers to add
        JB721TiersHook _hook = _initializeDelegateDefaultTiers(initialNumberOfTiers);

        JB721Tier[] memory _defaultStoredTiers = _hook.STORE().tiersOf(address(_hook), new uint256[](0), false, 0, 100);

        // Create new tiers to add
        (JB721TierConfig[] memory _tiersParamsToAdd, JB721Tier[] memory _tiersToAdd) =
            _createTiers(defaultTierConfig, numberOfFloorTiersToAdd, initialNumberOfTiers, floorTiersToAdd, 2);

        // remove 2 tiers and add the new ones
        uint256 _tiersLeft = initialNumberOfTiers;

        _tiersLeft = _addDeleteTiers(_hook, _tiersLeft, 0, _tiersParamsToAdd);

        JB721Tier[] memory _storedTiers = _hook.STORE().tiersOf(address(_hook), new uint256[](0), false, 0, 100);

        // Check: Expected number of tiers?
        assertEq(_storedTiers.length, _tiersLeft, "Length mismatch");

        // Check: Are all tiers in the new tiers (unsorted)?
        assertTrue(_isIn(_defaultStoredTiers, _storedTiers), "Original not included"); // Original tiers
        assertTrue(_isIn(_tiersToAdd, _storedTiers), "New not included"); // New tiers

        // Check: Are all the tiers sorted?
        for (uint256 i = 1; i < _storedTiers.length; i++) {
            assertLt(_storedTiers[i - 1].category, _storedTiers[i].category, "Sorting error");
        }
    }

    function testJBTieredNFTRewardDelegate_adjustTiers_addNewTiers(
        uint256 initialNumberOfTiers,
        uint256 numberOfFloorTiersToAdd,
        uint256 seed
    )
        public
    {
        // Include adding X new tiers when 0 preexisting ones
        initialNumberOfTiers = bound(initialNumberOfTiers, 0, 10);

        numberOfFloorTiersToAdd = bound(numberOfFloorTiersToAdd, 4, 14);
        uint16[] memory floorTiersToAdd = _createArray(numberOfFloorTiersToAdd, seed);

        // Floor are sorted in ascending orderen
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        // Initialize first tiers to add
        JB721TiersHook _hook = _initializeDelegateDefaultTiers(initialNumberOfTiers);

        JB721Tier[] memory _intialTiers = _hook.STORE().tiersOf(address(_hook), new uint256[](0), false, 0, 100);

        // Create new tiers to add
        (JB721TierConfig[] memory _tiersParams, JB721Tier[] memory _tiersAdded) =
            _createTiers(defaultTierConfig, numberOfFloorTiersToAdd, initialNumberOfTiers, floorTiersToAdd);

        // remove 2 tiers and add the new ones
        uint256 _tiersLeft = initialNumberOfTiers;

        _addDeleteTiers(_hook, _tiersLeft, 0, _tiersParams);

        JB721Tier[] memory _storedTiers = _hook.STORE().tiersOf(address(_hook), new uint256[](0), false, 0, 100);

        // Check: Expected number of tiers?
        assertEq(_storedTiers.length, _intialTiers.length + _tiersAdded.length, "Length mismatch");

        // Check: Are all tiers in the new tiers (unsorted)?
        assertTrue(_isIn(_intialTiers, _storedTiers), "original tiers not found"); // Original tiers
        assertTrue(_isIn(_tiersAdded, _storedTiers), "new tiers not found"); // New tiers

        // Check: Are all the tiers sorted?
        for (uint256 i = 1; i < _storedTiers.length; i++) {
            assertLe(_storedTiers[i - 1].category, _storedTiers[i].category, "Sorting error");
        }
    }

    function testJBTieredNFTRewardDelegate_adjustTiers_with_same_category_multiple_times(
        uint256 initialNumberOfTiers,
        uint256 numberOfFloorTiersToAdd,
        uint256 seed
    )
        public
    {
        initialNumberOfTiers = bound(initialNumberOfTiers, 2, 10);
        numberOfFloorTiersToAdd = bound(numberOfFloorTiersToAdd, 4, 14);

        uint16[] memory floorTiersToAdd = _createArray(numberOfFloorTiersToAdd, seed);

        // Floor are sorted in ascending orderen
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        // Initialize first tiers to add, uing a given category
        defaultTierConfig.category = 100;
        JB721TiersHook _hook = _initializeDelegateDefaultTiers(initialNumberOfTiers);

        // Create new tiers to add, with another category
        defaultTierConfig.category = 101;
        (JB721TierConfig[] memory _tiersParamsToAdd, JB721Tier[] memory _tiersToAdd) =
            _createTiers(defaultTierConfig, numberOfFloorTiersToAdd, initialNumberOfTiers, floorTiersToAdd);

        // add the new tiers
        _addDeleteTiers(_hook, 0, 0, _tiersParamsToAdd);

        // Create new tiers to add, with same category and different prices
        (_tiersParamsToAdd, _tiersToAdd) = _createTiers(defaultTierConfig, numberOfFloorTiersToAdd);

        _addDeleteTiers(_hook, 0, 0, _tiersParamsToAdd);

        // Check: All tiers stored?
        JB721Tier[] memory _storedTiers = _hook.STORE().tiersOf(address(_hook), new uint256[](0), false, 0, 100);
        assertEq(_storedTiers.length, initialNumberOfTiers + floorTiersToAdd.length * 2);

        // Check: Are all tiers in the new tiers (unsorted)?
        uint256[] memory _categories = new uint256[](1);
        _categories[0] = 101;

        JB721Tier[] memory _stored101Tiers =
            _hook.STORE().tiersOf(address(_hook), _categories, false, 0, floorTiersToAdd.length * 2);

        assertEq(_stored101Tiers.length, floorTiersToAdd.length * 2);

        // Check: Are all the tiers in the initial tiers?
        _categories[0] = 100;
        JB721Tier[] memory _stored100Tiers = _hook.STORE().tiersOf(address(_hook), _categories, false, 0, 100);
        assertEq(_stored100Tiers.length, initialNumberOfTiers);

        // Check: Order
        for (uint256 i; i < floorTiersToAdd.length; i++) {
            assertGt(_stored101Tiers[i].id, _stored101Tiers[i + floorTiersToAdd.length].id);
        }
    }

    function testJBTieredNFTRewardDelegate_adjustTiers_with_different_categories(
        uint256 initialNumberOfTiers,
        uint256 numberOfFloorTiersToAdd,
        uint256 seed
    )
        public
    {
        // Include adding X new tiers when 0 preexisting ones
        initialNumberOfTiers = bound(initialNumberOfTiers, 1, 10);

        numberOfFloorTiersToAdd = bound(numberOfFloorTiersToAdd, 1, 10);
        uint16[] memory floorTiersToAdd = _createArray(numberOfFloorTiersToAdd, seed);

        // Floor are sorted in ascending orderen
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        // Initialize first tiers to add
        defaultTierConfig.category = 100;
        JB721TiersHook _hook = _initializeDelegateDefaultTiers(initialNumberOfTiers);

        // Create new tiers to add
        defaultTierConfig.category = 101;
        (JB721TierConfig[] memory _tiersParams, JB721Tier[] memory _tiersAdded) =
            _createTiers(defaultTierConfig, numberOfFloorTiersToAdd, initialNumberOfTiers, floorTiersToAdd);

        // Add the new tiers
        uint256 _tiersLeft = initialNumberOfTiers;

        _tiersLeft = _addDeleteTiers(_hook, _tiersLeft, 0, _tiersParams);

        defaultTierConfig.category = 102;
        (_tiersParams, _tiersAdded) =
            _createTiers(defaultTierConfig, numberOfFloorTiersToAdd, initialNumberOfTiers, floorTiersToAdd);

        // Add the new tiers
        _tiersLeft = _addDeleteTiers(_hook, _tiersLeft, 0, _tiersParams);

        JB721Tier[] memory _allStoredTiers = _hook.STORE().tiersOf(address(_hook), new uint256[](0), false, 0, 100);

        uint256[] memory _categories = new uint256[](1);
        _categories[0] = 102;
        JB721Tier[] memory _stored102Tiers = _hook.STORE().tiersOf(address(_hook), _categories, false, 0, 100);

        assertEq(_stored102Tiers.length, floorTiersToAdd.length);

        for (uint256 i = 0; i < _stored102Tiers.length; i++) {
            assertEq(_stored102Tiers[i].category, uint8(102));
        }

        _categories[0] = 101;

        JB721Tier[] memory _stored101Tiers = _hook.STORE().tiersOf(address(_hook), _categories, false, 0, 100);

        assertEq(_stored101Tiers.length, floorTiersToAdd.length);

        for (uint256 i = 0; i < _stored101Tiers.length; i++) {
            assertEq(_stored101Tiers[i].category, uint8(101));
        }

        for (uint256 i = 1; i < initialNumberOfTiers + floorTiersToAdd.length * 2; i++) {
            assertGt(_allStoredTiers[i].id, _allStoredTiers[i - 1].id);
            assertLe(_allStoredTiers[i - 1].category, _allStoredTiers[i].category);
        }
    }

    function testJBTieredNFTRewardDelegate_adjustTiers_with_0_category(
        uint256 initialNumberOfTiers,
        uint256 numberOfFloorTiersToAdd,
        uint256 seed
    )
        public
    {
        initialNumberOfTiers = bound(initialNumberOfTiers, 2, 10);

        numberOfFloorTiersToAdd = bound(numberOfFloorTiersToAdd, 4, 14);
        uint16[] memory floorTiersToAdd = _createArray(numberOfFloorTiersToAdd, seed);

        // Floor are sorted in ascending orderen
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        // Initialize first tiers to add, category 0
        defaultTierConfig.category = 0;
        JB721TiersHook _hook = _initializeDelegateDefaultTiers(initialNumberOfTiers);

        // Create new tiers to add
        defaultTierConfig.category = 5;
        (JB721TierConfig[] memory _tiersParamsToAdd,) =
            _createTiers(defaultTierConfig, numberOfFloorTiersToAdd, initialNumberOfTiers, floorTiersToAdd, 2);

        uint256 _tiersLeft = initialNumberOfTiers;
        _tiersLeft = _addDeleteTiers(_hook, _tiersLeft, 0, _tiersParamsToAdd);

        uint256[] memory _categories = new uint256[](1);
        _categories[0] = 0;
        JB721Tier[] memory _allStoredTiers = _hook.STORE().tiersOf(address(_hook), _categories, false, 0, 100);

        assertEq(_allStoredTiers.length, initialNumberOfTiers);
        for (uint256 i = 0; i < _allStoredTiers.length; i++) {
            assertEq(_allStoredTiers[i].category, uint8(0));
        }
    }

    function testJBTieredNFTRewardDelegate_adjustTiers_with_different_categories_and_fetched_together(
        uint256 initialNumberOfTiers,
        uint256 numberOfFloorTiersToAdd,
        uint256 seed
    )
        public
    {
        initialNumberOfTiers = bound(initialNumberOfTiers, 1, 14);

        numberOfFloorTiersToAdd = bound(numberOfFloorTiersToAdd, 1, 14);
        uint16[] memory floorTiersToAdd = _createArray(numberOfFloorTiersToAdd, seed);

        // Floor are sorted in ascending orderen
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        // Initialize first tiers to add, category 0
        defaultTierConfig.category = 100;
        JB721TiersHook _hook = _initializeDelegateDefaultTiers(initialNumberOfTiers);

        // Create new tiers to add
        defaultTierConfig.category = 101;
        (JB721TierConfig[] memory _tiersParamsToAdd,) =
            _createTiers(defaultTierConfig, numberOfFloorTiersToAdd, initialNumberOfTiers, floorTiersToAdd);

        uint256 _tiersLeft = initialNumberOfTiers;
        _tiersLeft = _addDeleteTiers(_hook, _tiersLeft, 0, _tiersParamsToAdd);

        defaultTierConfig.category = 102;
        (_tiersParamsToAdd,) =
            _createTiers(defaultTierConfig, numberOfFloorTiersToAdd, initialNumberOfTiers, floorTiersToAdd);

        _tiersLeft = _addDeleteTiers(_hook, _tiersLeft, 0, _tiersParamsToAdd);

        uint256[] memory _categories = new uint256[](3);
        _categories[0] = 102;
        _categories[1] = 100;
        _categories[2] = 101;
        JB721Tier[] memory _allStoredTiers = _hook.STORE().tiersOf(address(_hook), _categories, false, 0, 100);

        assertEq(
            _allStoredTiers.length, initialNumberOfTiers + floorTiersToAdd.length * 2, "Wrong total number of tiers"
        );

        uint256 tier_100_max_index = _allStoredTiers.length - floorTiersToAdd.length;

        for (uint256 i = 0; i < floorTiersToAdd.length; i++) {
            assertEq(_allStoredTiers[i].category, uint8(102), "wrong first cat");
        }

        for (uint256 i = floorTiersToAdd.length; i < tier_100_max_index; i++) {
            assertEq(_allStoredTiers[i].category, uint8(100), "wrong second cat");
        }

        for (uint256 i = tier_100_max_index; i < _allStoredTiers.length; i++) {
            assertEq(_allStoredTiers[i].category, uint8(101), "wrong third cat");
        }
    }

    function testJBTieredNFTRewardDelegate_adjustTiers_addNewTiers_fetch_specifc_tier(
        uint256 initialNumberOfTiers,
        uint256 numberOfFloorTiersToAdd,
        uint256 seed
    )
        public
    {
        initialNumberOfTiers = bound(initialNumberOfTiers, 1, 14);

        numberOfFloorTiersToAdd = bound(numberOfFloorTiersToAdd, 1, 14);
        uint16[] memory floorTiersToAdd = _createArray(numberOfFloorTiersToAdd, seed);

        // Floor are sorted in ascending orderen
        floorTiersToAdd = _sortArray(floorTiersToAdd);

        // Initialize first tiers to add, category 0
        defaultTierConfig.category = 100;
        JB721TiersHook _hook = _initializeDelegateDefaultTiers(initialNumberOfTiers);

        // Create new tiers to add
        defaultTierConfig.category = 101;
        (JB721TierConfig[] memory _tiersParamsToAdd,) =
            _createTiers(defaultTierConfig, numberOfFloorTiersToAdd, initialNumberOfTiers, floorTiersToAdd);

        uint256 _tiersLeft = initialNumberOfTiers;
        _tiersLeft = _addDeleteTiers(_hook, _tiersLeft, 0, _tiersParamsToAdd);

        uint256[] memory _categories = new uint256[](1);
        _categories[0] = 101;
        JB721Tier[] memory _storedTiers =
            _hook.STORE().tiersOf(address(_hook), _categories, false, 0, initialNumberOfTiers + floorTiersToAdd.length);
        // check no of tiers
        assertEq(_storedTiers.length, floorTiersToAdd.length);
        // Check: Are all the tiers sorted?
        for (uint256 i = 0; i < _storedTiers.length; i++) {
            assertEq(_storedTiers[i].category, uint8(101));
        }
    }

    function testJBTieredNFTRewardDelegate_adjustTiers_removeTiers(
        uint256 initialNumberOfTiers,
        uint256 seed,
        uint256 numberOfTiersToRemove
    )
        public
    {
        initialNumberOfTiers = bound(initialNumberOfTiers, 0, 14);
        numberOfTiersToRemove = bound(numberOfTiersToRemove, 0, initialNumberOfTiers);

        // Create random tiers to remove
        uint256[] memory tiersToRemove = new uint256[](numberOfTiersToRemove);

        // seed to generate new random tiers, i to iterate to fill the tiersToRemove array
        for (uint256 i; i < numberOfTiersToRemove;) {
            uint256 _newTierCandidate = uint256(keccak256(abi.encode(seed))) % initialNumberOfTiers + 1;
            bool _invalidTier;
            if (_newTierCandidate != 0) {
                for (uint256 j; j < numberOfTiersToRemove; j++) {
                    // Same value twice?
                    if (_newTierCandidate == tiersToRemove[j]) {
                        _invalidTier = true;
                        break;
                    }
                }
                if (!_invalidTier) {
                    tiersToRemove[i] = _newTierCandidate;
                    i++;
                }
            }
            // Overflow to loop over (seed is fuzzed, can be starting at max(uint256))
            unchecked {
                seed++;
            }
        }

        // Order the tiers to remove for event matching (which are ordered too)
        tiersToRemove = _sortArray(tiersToRemove);
        JB721TierConfig[] memory _tierParams = new JB721TierConfig[](initialNumberOfTiers);
        JB721Tier[] memory _tiers = new JB721Tier[](initialNumberOfTiers);

        for (uint256 i; i < initialNumberOfTiers; i++) {
            _tierParams[i] = JB721TierConfig({
                price: uint104((i + 1) * 10),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(i),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: true
            });
            _tiers[i] = JB721Tier({
                id: i + 1,
                price: _tierParams[i].price,
                remainingSupply: _tierParams[i].initialSupply,
                initialSupply: _tierParams[i].initialSupply,
                votingUnits: _tierParams[i].votingUnits,
                reserveFrequency: _tierParams[i].reserveFrequency,
                reserveBeneficiary: _tierParams[i].reserveBeneficiary,
                encodedIPFSUri: _tierParams[i].encodedIPFSUri,
                category: _tierParams[i].category,
                allowOwnerMint: _tierParams[i].allowOwnerMint,
                transfersPausable: _tierParams[i].transfersPausable,
                resolvedUri: ""
            });
        }
        ForTest_JB721TiersHookStore _ForTest_store = new ForTest_JB721TiersHookStore();
        ForTest_JB721TiersHook _hook = new ForTest_JB721TiersHook(
            projectId,
            IJBDirectory(mockJBDirectory),
            name,
            symbol,
            IJBRulesets(mockJBRulesets),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            _tierParams,
            IJB721TiersHookStore(address(_ForTest_store)),
            JB721TiersHookFlags({
                preventOverspending: false,
                noNewTiersWithReserves: false,
                noNewTiersWithVotes: false,
                noNewTiersWithOwnerMinting: true
            })
        );
        _hook.transferOwnership(owner);

        // Will be resized later
        JB721TierConfig[] memory tierParamsRemaining = new JB721TierConfig[](initialNumberOfTiers);
        JB721Tier[] memory tiersRemaining = new JB721Tier[](initialNumberOfTiers);
        for (uint256 i; i < _tiers.length; i++) {
            tierParamsRemaining[i] = _tierParams[i];
            tiersRemaining[i] = _tiers[i];
        }
        for (uint256 i; i < tiersRemaining.length;) {
            bool _swappedAndPopped;
            for (uint256 j; j < tiersToRemove.length; j++) {
                if (tiersRemaining[i].id == tiersToRemove[j]) {
                    // Swap and pop tiers removed
                    tiersRemaining[i] = tiersRemaining[tiersRemaining.length - 1];
                    tierParamsRemaining[i] = tierParamsRemaining[tierParamsRemaining.length - 1];
                    // Remove the last elelment / reduce array length by 1
                    assembly ("memory-safe") {
                        mstore(tiersRemaining, sub(mload(tiersRemaining), 1))
                        mstore(tierParamsRemaining, sub(mload(tierParamsRemaining), 1))
                    }
                    _swappedAndPopped = true;
                    break;
                }
            }
            if (!_swappedAndPopped) i++;
        }
        // Check: correct event params?
        for (uint256 i; i < tiersToRemove.length; i++) {
            vm.expectEmit(true, false, false, true, address(_hook));
            emit RemoveTier(tiersToRemove[i], owner);
        }
        vm.prank(owner);
        _hook.adjustTiers(new JB721TierConfig[](0), tiersToRemove);
        {
            uint256 finalNumberOfTiers = initialNumberOfTiers - tiersToRemove.length;
            JB721Tier[] memory _storedTiers =
                _hook.test_store().tiersOf(address(_hook), new uint256[](0), false, 0, finalNumberOfTiers);
            // Check expected number of tiers remainings
            assertEq(_storedTiers.length, finalNumberOfTiers);
            // Check that all the remaining tiers still exist
            assertTrue(_isIn(tiersRemaining, _storedTiers));
            // Check that none of the removed tiers still exist
            assertTrue(_isIn(_storedTiers, tiersRemaining));
        }
    }

    function testJBTieredNFTRewardDelegate_adjustTiers_addAndRemoveTiers() public {
        uint256 initialNumberOfTiers = 5;
        uint256 numberOfTiersToAdd = 5;
        uint256 numberOfTiersToRemove = 3;
        uint256[] memory floorTiersToAdd = new uint256[](numberOfTiersToAdd);
        floorTiersToAdd[0] = 1;
        floorTiersToAdd[1] = 4;
        floorTiersToAdd[2] = 5;
        floorTiersToAdd[3] = 6;
        floorTiersToAdd[4] = 10;
        uint256[] memory tierIdToRemove = new uint256[](numberOfTiersToRemove);
        tierIdToRemove[0] = 1;
        tierIdToRemove[1] = 3;
        tierIdToRemove[2] = 4;
        // Initial tiers data
        JB721TierConfig[] memory _tierParams = new JB721TierConfig[](initialNumberOfTiers);
        JB721Tier[] memory _tiers = new JB721Tier[](initialNumberOfTiers);
        for (uint256 i; i < initialNumberOfTiers; i++) {
            _tierParams[i] = JB721TierConfig({
                price: uint104((i + 1) * 10),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(i),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: true
            });
            _tiers[i] = JB721Tier({
                id: i + 1,
                price: _tierParams[i].price,
                remainingSupply: _tierParams[i].initialSupply,
                initialSupply: _tierParams[i].initialSupply,
                votingUnits: _tierParams[i].votingUnits,
                reserveFrequency: _tierParams[i].reserveFrequency,
                reserveBeneficiary: _tierParams[i].reserveBeneficiary,
                encodedIPFSUri: _tierParams[i].encodedIPFSUri,
                category: _tierParams[i].category,
                allowOwnerMint: _tierParams[i].allowOwnerMint,
                transfersPausable: _tierParams[i].transfersPausable,
                resolvedUri: ""
            });
        }
        //  Deploy the hook with the initial tiers
        JB721TiersHookStore _store = new JB721TiersHookStore();
        vm.etch(hook_i, address(hook).code);
        JB721TiersHook _hook = JB721TiersHook(hook_i);
        _hook.initialize(
            projectId,
            name,
            symbol,
            IJBRulesets(mockJBRulesets),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            JB721InitTiersConfig({
                tiers: _tierParams,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
                decimals: 18,
                prices: IJBPrices(address(0))
            }),
            IJB721TiersHookStore(address(_store)),
            JB721TiersHookFlags({
                preventOverspending: false,
                noNewTiersWithReserves: false,
                noNewTiersWithVotes: false,
                noNewTiersWithOwnerMinting: true
            })
        );
        _hook.transferOwnership(owner);
        // -- Build expected removed/remaining tiers --
        JB721TierConfig[] memory _tierDataRemaining = new JB721TierConfig[](2);
        JB721Tier[] memory _tiersRemaining = new JB721Tier[](2);
        uint256 _arrayIndex;
        for (uint256 i; i < initialNumberOfTiers; i++) {
            // Tiers which will remain
            if (i + 1 != 1 && i + 1 != 3 && i + 1 != 4) {
                _tierDataRemaining[_arrayIndex] = JB721TierConfig({
                    price: uint104((i + 1) * 10),
                    initialSupply: uint32(100),
                    votingUnits: uint16(0),
                    reserveFrequency: uint16(i),
                    reserveBeneficiary: reserveBeneficiary,
                    encodedIPFSUri: tokenUris[0],
                    category: uint24(100),
                    allowOwnerMint: false,
                    useReserveBeneficiaryAsDefault: false,
                    transfersPausable: false,
                    useVotingUnits: true
                });
                _tiersRemaining[_arrayIndex] = JB721Tier({
                    id: i + 1,
                    price: _tierDataRemaining[_arrayIndex].price,
                    remainingSupply: _tierDataRemaining[_arrayIndex].initialSupply,
                    initialSupply: _tierDataRemaining[_arrayIndex].initialSupply,
                    votingUnits: _tierDataRemaining[_arrayIndex].votingUnits,
                    reserveFrequency: _tierDataRemaining[_arrayIndex].reserveFrequency,
                    reserveBeneficiary: _tierDataRemaining[_arrayIndex].reserveBeneficiary,
                    encodedIPFSUri: _tierDataRemaining[_arrayIndex].encodedIPFSUri,
                    category: _tierDataRemaining[_arrayIndex].category,
                    allowOwnerMint: _tierDataRemaining[_arrayIndex].allowOwnerMint,
                    transfersPausable: _tierDataRemaining[_arrayIndex].transfersPausable,
                    resolvedUri: ""
                });
                _arrayIndex++;
            } else {
                // Otherwise, part of the tiers removed:
                // Check: correct event params?
                vm.expectEmit(true, false, false, true, address(_hook));
                emit RemoveTier(i + 1, owner);
            }
        }
        // -- Build expected added tiers --
        JB721TierConfig[] memory _tierParamsToAdd = new JB721TierConfig[](numberOfTiersToAdd);
        JB721Tier[] memory _tiersAdded = new JB721Tier[](numberOfTiersToAdd);
        for (uint256 i; i < numberOfTiersToAdd; i++) {
            _tierParamsToAdd[i] = JB721TierConfig({
                price: uint104(floorTiersToAdd[i]) * 11,
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(0),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100 + i),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: true
            });
            _tiersAdded[i] = JB721Tier({
                id: _tiers.length + (i + 1),
                price: _tierParamsToAdd[i].price,
                remainingSupply: _tierParamsToAdd[i].initialSupply,
                initialSupply: _tierParamsToAdd[i].initialSupply,
                votingUnits: _tierParamsToAdd[i].votingUnits,
                reserveFrequency: _tierParamsToAdd[i].reserveFrequency,
                reserveBeneficiary: _tierParamsToAdd[i].reserveBeneficiary,
                encodedIPFSUri: _tierParamsToAdd[i].encodedIPFSUri,
                category: _tierParamsToAdd[i].category,
                allowOwnerMint: _tierParamsToAdd[i].allowOwnerMint,
                transfersPausable: _tierParamsToAdd[i].transfersPausable,
                resolvedUri: ""
            });
            vm.expectEmit(true, true, true, true, address(_hook));
            emit AddTier(_tiersAdded[i].id, _tierParamsToAdd[i], owner);
        }
        vm.prank(owner);
        _hook.adjustTiers(_tierParamsToAdd, tierIdToRemove);
        JB721Tier[] memory _storedTiers = _hook.STORE().tiersOf(
            address(_hook),
            new uint256[](0),
            false,
            0,
            7 // 7 tiers remaining - Hardcoded to avoid stack too deep
        );
        // Check: Expected number of remaining tiers?
        assertEq(_storedTiers.length, 7);
        // // Check: Are all non-deleted and added tiers in the new tiers (unsorted)?
        assertTrue(_isIn(_tiersRemaining, _storedTiers)); // Original tiers
        assertTrue(_isIn(_tiersAdded, _storedTiers)); // New tiers
        // Check: Are all the deleted tiers removed (remaining is tested supra)?
        assertFalse(_isIn(_tiers, _storedTiers)); // Will emit _isIn: incomplete inclusion but without failing assertion
        // Check: Are all the tiers sorted?
        for (uint256 j = 1; j < _storedTiers.length; j++) {
            assertLe(_storedTiers[j - 1].category, _storedTiers[j].category);
        }
    }

    function testJBTieredNFTRewardDelegate_adjustTiers_revertIfAddingWithVotingPower(
        uint256 initialNumberOfTiers,
        uint256 numberTiersToAdd
    )
        public
    {
        // Include adding X new tiers when 0 preexisting ones
        initialNumberOfTiers = bound(initialNumberOfTiers, 0, 15);
        numberTiersToAdd = bound(numberTiersToAdd, 1, 15);

        JB721TierConfig[] memory _tierParams = new JB721TierConfig[](initialNumberOfTiers);
        JB721Tier[] memory _tiers = new JB721Tier[](initialNumberOfTiers);
        for (uint256 i; i < initialNumberOfTiers; i++) {
            _tierParams[i] = JB721TierConfig({
                price: uint104((i + 1) * 10),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(i),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: true
            });
            _tiers[i] = JB721Tier({
                id: i + 1,
                price: _tierParams[i].price,
                remainingSupply: _tierParams[i].initialSupply,
                initialSupply: _tierParams[i].initialSupply,
                votingUnits: _tierParams[i].votingUnits,
                reserveFrequency: _tierParams[i].reserveFrequency,
                reserveBeneficiary: _tierParams[i].reserveBeneficiary,
                encodedIPFSUri: _tierParams[i].encodedIPFSUri,
                category: _tierParams[i].category,
                allowOwnerMint: _tierParams[i].allowOwnerMint,
                transfersPausable: _tierParams[i].transfersPausable,
                resolvedUri: ""
            });
        }
        ForTest_JB721TiersHookStore _ForTest_store = new ForTest_JB721TiersHookStore();
        ForTest_JB721TiersHook _hook = new ForTest_JB721TiersHook(
            projectId,
            IJBDirectory(mockJBDirectory),
            name,
            symbol,
            IJBRulesets(mockJBRulesets),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            _tierParams,
            IJB721TiersHookStore(address(_ForTest_store)),
            JB721TiersHookFlags({
                preventOverspending: false,
                noNewTiersWithReserves: false,
                noNewTiersWithVotes: true,
                noNewTiersWithOwnerMinting: true
            })
        );
        _hook.transferOwnership(owner);
        JB721TierConfig[] memory _tierParamsToAdd = new JB721TierConfig[](numberTiersToAdd);
        JB721Tier[] memory _tiersAdded = new JB721Tier[](numberTiersToAdd);
        for (uint256 i; i < numberTiersToAdd; i++) {
            _tierParamsToAdd[i] = JB721TierConfig({
                price: uint104(0),
                initialSupply: uint32(100),
                votingUnits: uint16(i + 1),
                reserveFrequency: uint16(i),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: true
            });
            _tiersAdded[i] = JB721Tier({
                id: _tiers.length + (i + 1),
                price: _tierParamsToAdd[i].price,
                remainingSupply: _tierParamsToAdd[i].initialSupply,
                initialSupply: _tierParamsToAdd[i].initialSupply,
                votingUnits: _tierParamsToAdd[i].votingUnits,
                reserveFrequency: _tierParamsToAdd[i].reserveFrequency,
                reserveBeneficiary: _tierParamsToAdd[i].reserveBeneficiary,
                encodedIPFSUri: _tierParamsToAdd[i].encodedIPFSUri,
                category: _tierParamsToAdd[i].category,
                allowOwnerMint: _tierParamsToAdd[i].allowOwnerMint,
                transfersPausable: _tierParamsToAdd[i].transfersPausable,
                resolvedUri: ""
            });
        }
        vm.expectRevert(abi.encodeWithSelector(JB721TiersHookStore.VOTING_UNITS_NOT_ALLOWED.selector));
        vm.prank(owner);
        _hook.adjustTiers(_tierParamsToAdd, new uint256[](0));
    }

    function testJBTieredNFTRewardDelegate_adjustTiers_revertIfAddingWithreserveFrequency(
        uint256 initialNumberOfTiers,
        uint256 numberTiersToAdd
    )
        public
    {
        // Include adding X new tiers when 0 preexisting ones
        initialNumberOfTiers = bound(initialNumberOfTiers, 0, 15);
        numberTiersToAdd = bound(numberTiersToAdd, 1, 15);

        JB721TierConfig[] memory _tierParam = new JB721TierConfig[](initialNumberOfTiers);
        JB721Tier[] memory _tiers = new JB721Tier[](initialNumberOfTiers);
        for (uint256 i; i < initialNumberOfTiers; i++) {
            _tierParam[i] = JB721TierConfig({
                price: uint104((i + 1) * 10),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(i),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: true
            });
            _tiers[i] = JB721Tier({
                id: i + 1,
                price: _tierParam[i].price,
                remainingSupply: _tierParam[i].initialSupply,
                initialSupply: _tierParam[i].initialSupply,
                votingUnits: _tierParam[i].votingUnits,
                reserveFrequency: _tierParam[i].reserveFrequency,
                reserveBeneficiary: _tierParam[i].reserveBeneficiary,
                encodedIPFSUri: _tierParam[i].encodedIPFSUri,
                category: _tierParam[i].category,
                allowOwnerMint: _tierParam[i].allowOwnerMint,
                transfersPausable: _tierParam[i].transfersPausable,
                resolvedUri: ""
            });
        }
        ForTest_JB721TiersHookStore _ForTest_store = new ForTest_JB721TiersHookStore();
        ForTest_JB721TiersHook _hook = new ForTest_JB721TiersHook(
            projectId,
            IJBDirectory(mockJBDirectory),
            name,
            symbol,
            IJBRulesets(mockJBRulesets),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            _tierParam,
            IJB721TiersHookStore(address(_ForTest_store)),
            JB721TiersHookFlags({
                preventOverspending: false,
                noNewTiersWithReserves: true,
                noNewTiersWithVotes: false,
                noNewTiersWithOwnerMinting: true
            })
        );
        _hook.transferOwnership(owner);
        JB721TierConfig[] memory _tierParamsToAdd = new JB721TierConfig[](numberTiersToAdd);
        JB721Tier[] memory _tiersAdded = new JB721Tier[](numberTiersToAdd);
        for (uint256 i; i < numberTiersToAdd; i++) {
            _tierParamsToAdd[i] = JB721TierConfig({
                price: uint104((i + 1) * 100),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(i + 1),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: true
            });
            _tiersAdded[i] = JB721Tier({
                id: _tiers.length + (i + 1),
                price: _tierParamsToAdd[i].price,
                remainingSupply: _tierParamsToAdd[i].initialSupply,
                initialSupply: _tierParamsToAdd[i].initialSupply,
                votingUnits: _tierParamsToAdd[i].votingUnits,
                reserveFrequency: _tierParamsToAdd[i].reserveFrequency,
                reserveBeneficiary: _tierParamsToAdd[i].reserveBeneficiary,
                encodedIPFSUri: _tierParamsToAdd[i].encodedIPFSUri,
                category: _tierParamsToAdd[i].category,
                allowOwnerMint: _tierParamsToAdd[i].allowOwnerMint,
                transfersPausable: _tierParamsToAdd[i].transfersPausable,
                resolvedUri: ""
            });
        }
        vm.expectRevert(abi.encodeWithSelector(JB721TiersHookStore.RESERVE_FREQUENCY_NOT_ALLOWED.selector));
        vm.prank(owner);
        _hook.adjustTiers(_tierParamsToAdd, new uint256[](0));
    }

    function testJBTieredNFTRewardDelegate_adjustTiers_revertIfEmptyQuantity(
        uint256 initialNumberOfTiers,
        uint256 numberTiersToAdd
    )
        public
    {
        // Include adding X new tiers when 0 preexisting ones
        initialNumberOfTiers = bound(initialNumberOfTiers, 0, 15);
        numberTiersToAdd = bound(numberTiersToAdd, 1, 15);

        JB721TierConfig[] memory _tierParams = new JB721TierConfig[](initialNumberOfTiers);
        JB721Tier[] memory _tiers = new JB721Tier[](initialNumberOfTiers);
        for (uint256 i; i < initialNumberOfTiers; i++) {
            _tierParams[i] = JB721TierConfig({
                price: uint104((i + 1) * 10),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(i),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: true
            });
            _tiers[i] = JB721Tier({
                id: i + 1,
                price: _tierParams[i].price,
                remainingSupply: _tierParams[i].initialSupply,
                initialSupply: _tierParams[i].initialSupply,
                votingUnits: _tierParams[i].votingUnits,
                reserveFrequency: _tierParams[i].reserveFrequency,
                reserveBeneficiary: _tierParams[i].reserveBeneficiary,
                encodedIPFSUri: _tierParams[i].encodedIPFSUri,
                category: _tierParams[i].category,
                allowOwnerMint: _tierParams[i].allowOwnerMint,
                transfersPausable: _tierParams[i].transfersPausable,
                resolvedUri: ""
            });
        }
        ForTest_JB721TiersHookStore _ForTest_store = new ForTest_JB721TiersHookStore();
        ForTest_JB721TiersHook _hook = new ForTest_JB721TiersHook(
            projectId,
            IJBDirectory(mockJBDirectory),
            name,
            symbol,
            IJBRulesets(mockJBRulesets),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            _tierParams,
            IJB721TiersHookStore(address(_ForTest_store)),
            JB721TiersHookFlags({
                preventOverspending: false,
                noNewTiersWithReserves: false,
                noNewTiersWithVotes: false,
                noNewTiersWithOwnerMinting: true
            })
        );
        _hook.transferOwnership(owner);
        JB721TierConfig[] memory _tierParamsToAdd = new JB721TierConfig[](numberTiersToAdd);
        JB721Tier[] memory _tiersAdded = new JB721Tier[](numberTiersToAdd);
        for (uint256 i; i < numberTiersToAdd; i++) {
            _tierParamsToAdd[i] = JB721TierConfig({
                price: uint104((i + 1) * 100),
                initialSupply: uint32(0),
                votingUnits: uint16(0),
                reserveFrequency: uint16(0),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: false
            });
            _tiersAdded[i] = JB721Tier({
                id: _tiers.length + (i + 1),
                price: _tierParamsToAdd[i].price,
                remainingSupply: _tierParamsToAdd[i].initialSupply,
                initialSupply: _tierParamsToAdd[i].initialSupply,
                votingUnits: _tierParamsToAdd[i].votingUnits,
                reserveFrequency: _tierParamsToAdd[i].reserveFrequency,
                reserveBeneficiary: _tierParamsToAdd[i].reserveBeneficiary,
                encodedIPFSUri: _tierParamsToAdd[i].encodedIPFSUri,
                category: _tierParamsToAdd[i].category,
                allowOwnerMint: _tierParamsToAdd[i].allowOwnerMint,
                transfersPausable: _tierParamsToAdd[i].transfersPausable,
                resolvedUri: ""
            });
        }
        vm.expectRevert(abi.encodeWithSelector(JB721TiersHookStore.NO_SUPPLY.selector));
        vm.prank(owner);
        _hook.adjustTiers(_tierParamsToAdd, new uint256[](0));
    }

    function testJBTieredNFTRewardDelegate_adjustTiers_revertIfRemovingALockedTier(
        uint256 initialNumberOfTiers,
        uint256 tierLockedIndex
    )
        public
    {
        initialNumberOfTiers = bound(initialNumberOfTiers, 1, 15);
        tierLockedIndex = bound(tierLockedIndex, 0, initialNumberOfTiers - 1);

        JB721TierConfig[] memory _tierParams = new JB721TierConfig[](initialNumberOfTiers);
        JB721Tier[] memory _tiers = new JB721Tier[](initialNumberOfTiers);
        for (uint256 i; i < initialNumberOfTiers; i++) {
            _tierParams[i] = JB721TierConfig({
                price: uint104((i + 1) * 10),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(i),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: false
            });
            _tiers[i] = JB721Tier({
                id: i + 1,
                price: _tierParams[i].price,
                remainingSupply: _tierParams[i].initialSupply,
                initialSupply: _tierParams[i].initialSupply,
                votingUnits: _tierParams[i].votingUnits,
                reserveFrequency: _tierParams[i].reserveFrequency,
                reserveBeneficiary: _tierParams[i].reserveBeneficiary,
                encodedIPFSUri: _tierParams[i].encodedIPFSUri,
                category: _tierParams[i].category,
                allowOwnerMint: _tierParams[i].allowOwnerMint,
                transfersPausable: _tierParams[i].transfersPausable,
                resolvedUri: ""
            });
        }
        JB721TiersHookStore _store = new JB721TiersHookStore();
        vm.etch(hook_i, address(hook).code);
        JB721TiersHook _hook = JB721TiersHook(hook_i);
        _hook.initialize(
            projectId,
            name,
            symbol,
            IJBRulesets(mockJBRulesets),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            JB721InitTiersConfig({
                tiers: _tierParams,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
                decimals: 18,
                prices: IJBPrices(address(0))
            }),
            IJB721TiersHookStore(address(_store)),
            JB721TiersHookFlags({
                preventOverspending: false,
                noNewTiersWithReserves: false,
                noNewTiersWithVotes: false,
                noNewTiersWithOwnerMinting: true
            })
        );
        _hook.transferOwnership(owner);
        uint256[] memory _tierToRemove = new uint256[](1);
        _tierToRemove[0] = tierLockedIndex + 1;
        // Check: reomve tier after lock
        vm.warp(block.timestamp + 11);
        vm.prank(owner);
        _hook.adjustTiers(new JB721TierConfig[](0), _tierToRemove);
        // Check: one less tier
        assertEq(
            _hook.STORE().tiersOf(address(_hook), new uint256[](0), false, 0, initialNumberOfTiers).length,
            initialNumberOfTiers - 1
        );
    }

    function testJBTieredNFTRewardDelegate_adjustTiers_revertIfInvalidCategorySortOrder(
        uint256 initialNumberOfTiers,
        uint256 numberTiersToAdd
    )
        public
    {
        initialNumberOfTiers = bound(initialNumberOfTiers, 0, 15);
        numberTiersToAdd = bound(numberTiersToAdd, 2, 15);

        ForTest_JB721TiersHook _hook = _initializeForTestHook(initialNumberOfTiers);

        JB721TierConfig[] memory _tierParamsToAdd = new JB721TierConfig[](numberTiersToAdd);
        for (uint256 i; i < numberTiersToAdd; i++) {
            _tierParamsToAdd[i] = JB721TierConfig({
                price: uint104((i + 1) * 100),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(i),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: true
            });
        }
        _tierParamsToAdd[numberTiersToAdd - 1].category = uint8(99);

        vm.expectRevert(abi.encodeWithSelector(JB721TiersHookStore.INVALID_CATEGORY_SORT_ORDER.selector));
        vm.prank(owner);
        _hook.adjustTiers(_tierParamsToAdd, new uint256[](0));
    }

    function testJBTieredNFTRewardDelegate_adjustTiers_revertIfMoreVotingUnitsNotAllowedWithPriceChange(
        uint256 initialNumberOfTiers,
        uint256 numberTiersToAdd
    )
        public
    {
        // Include adding X new tiers when 0 preexisting ones
        initialNumberOfTiers = bound(initialNumberOfTiers, 0, 15);
        numberTiersToAdd = bound(numberTiersToAdd, 1, 15);

        JB721TierConfig[] memory _tierParams = new JB721TierConfig[](initialNumberOfTiers);
        for (uint256 i; i < initialNumberOfTiers; i++) {
            _tierParams[i] = JB721TierConfig({
                price: uint104((i + 1) * 10),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(i),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: false
            });
        }

        ForTest_JB721TiersHookStore _ForTest_store = new ForTest_JB721TiersHookStore();
        ForTest_JB721TiersHook _hook = new ForTest_JB721TiersHook(
            projectId,
            IJBDirectory(mockJBDirectory),
            name,
            symbol,
            IJBRulesets(mockJBRulesets),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            _tierParams,
            IJB721TiersHookStore(address(_ForTest_store)),
            JB721TiersHookFlags({
                preventOverspending: false,
                noNewTiersWithReserves: false,
                noNewTiersWithVotes: true,
                noNewTiersWithOwnerMinting: true
            })
        );
        _hook.transferOwnership(owner);

        JB721TierConfig[] memory _tierParamsToAdd = new JB721TierConfig[](numberTiersToAdd);
        for (uint256 i; i < numberTiersToAdd; i++) {
            _tierParamsToAdd[i] = JB721TierConfig({
                price: uint104((i + 1) * 100),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(i),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: false
            });
        }
        _tierParamsToAdd[numberTiersToAdd - 1].category = uint8(99);
        vm.expectRevert(abi.encodeWithSelector(JB721TiersHookStore.VOTING_UNITS_NOT_ALLOWED.selector));
        vm.prank(owner);
        _hook.adjustTiers(_tierParamsToAdd, new uint256[](0));
    }

    function testJBTieredNFTRewardDelegate_cleanTiers_removeTheInactiveTiers(
        uint256 initialNumberOfTiers,
        uint256 seed,
        uint256 numberOfTiersToRemove
    )
        public
    {
        // Include adding X new tiers when 0 preexisting ones
        initialNumberOfTiers = bound(initialNumberOfTiers, 1, 15);
        numberOfTiersToRemove = bound(numberOfTiersToRemove, 0, initialNumberOfTiers - 1);

        // Create random tiers to remove
        uint256[] memory tiersToRemove = new uint256[](numberOfTiersToRemove);
        // seed to generate new random tiers, i to iterate to fill the tiersToRemove array
        for (uint256 i; i < numberOfTiersToRemove;) {
            uint256 _newTierCandidate = uint256(keccak256(abi.encode(seed))) % initialNumberOfTiers;
            bool _invalidTier;
            if (_newTierCandidate != 0) {
                for (uint256 j; j < numberOfTiersToRemove; j++) {
                    // Same value twice?
                    if (_newTierCandidate == tiersToRemove[j]) {
                        _invalidTier = true;
                        break;
                    }
                }
                if (!_invalidTier) {
                    tiersToRemove[i] = _newTierCandidate;
                    i++;
                }
            }
            // Overflow to loop over (seed is fuzzed, can be starting at max(uint256))
            unchecked {
                seed++;
            }
        }
        // Order the tiers to remove for event matching (which are ordered too)
        tiersToRemove = _sortArray(tiersToRemove);
        JB721TierConfig[] memory _tierParams = new JB721TierConfig[](initialNumberOfTiers);
        JB721Tier[] memory _tiers = new JB721Tier[](initialNumberOfTiers);
        for (uint256 i; i < initialNumberOfTiers; i++) {
            _tierParams[i] = JB721TierConfig({
                price: uint104((i + 1) * 10),
                initialSupply: uint32(100),
                votingUnits: uint16(0),
                reserveFrequency: uint16(i),
                reserveBeneficiary: reserveBeneficiary,
                encodedIPFSUri: tokenUris[0],
                category: uint24(100),
                allowOwnerMint: false,
                useReserveBeneficiaryAsDefault: false,
                transfersPausable: false,
                useVotingUnits: false
            });
            _tiers[i] = JB721Tier({
                id: i + 1,
                price: _tierParams[i].price,
                remainingSupply: _tierParams[i].initialSupply,
                initialSupply: _tierParams[i].initialSupply,
                votingUnits: _tierParams[i].votingUnits,
                reserveFrequency: _tierParams[i].reserveFrequency,
                reserveBeneficiary: _tierParams[i].reserveBeneficiary,
                encodedIPFSUri: _tierParams[i].encodedIPFSUri,
                category: _tierParams[i].category,
                allowOwnerMint: _tierParams[i].allowOwnerMint,
                transfersPausable: _tierParams[i].transfersPausable,
                resolvedUri: ""
            });
        }
        ForTest_JB721TiersHookStore _ForTest_store = new ForTest_JB721TiersHookStore();
        ForTest_JB721TiersHook _hook = new ForTest_JB721TiersHook(
            projectId,
            IJBDirectory(mockJBDirectory),
            name,
            symbol,
            IJBRulesets(mockJBRulesets),
            baseUri,
            IJB721TokenUriResolver(mockTokenUriResolver),
            contractUri,
            _tierParams,
            IJB721TiersHookStore(address(_ForTest_store)),
            JB721TiersHookFlags({
                preventOverspending: false,
                noNewTiersWithReserves: false,
                noNewTiersWithVotes: false,
                noNewTiersWithOwnerMinting: true
            })
        );
        _hook.transferOwnership(owner);
        // Will be resized later
        JB721TierConfig[] memory tierParamsRemaining = new JB721TierConfig[](initialNumberOfTiers);
        JB721Tier[] memory tiersRemaining = new JB721Tier[](initialNumberOfTiers);
        for (uint256 i; i < _tiers.length; i++) {
            tierParamsRemaining[i] = _tierParams[i];
            tiersRemaining[i] = _tiers[i];
        }
        for (uint256 i; i < tiersRemaining.length;) {
            bool _swappedAndPopped;
            for (uint256 j; j < tiersToRemove.length; j++) {
                if (tiersRemaining[i].id == tiersToRemove[j]) {
                    // Swap and pop tiers removed
                    tiersRemaining[i] = tiersRemaining[tiersRemaining.length - 1];
                    tierParamsRemaining[i] = tierParamsRemaining[tierParamsRemaining.length - 1];
                    // Remove the last elelment / reduce array length by 1
                    assembly ("memory-safe") {
                        mstore(tiersRemaining, sub(mload(tiersRemaining), 1))
                        mstore(tierParamsRemaining, sub(mload(tierParamsRemaining), 1))
                    }
                    _swappedAndPopped = true;
                    break;
                }
            }
            if (!_swappedAndPopped) i++;
        }
        vm.prank(owner);
        _hook.adjustTiers(new JB721TierConfig[](0), tiersToRemove);
        JB721Tier[] memory _tiersListDump = _hook.test_store().ForTest_dumpTiersList(address(_hook));
        // Check: all the tiers are still in the linked list (both active and inactives)
        assertTrue(_isIn(_tiers, _tiersListDump));
        // Check: the linked list include only the tiers (active and inactives)
        assertTrue(_isIn(_tiersListDump, _tiers));
        // Check: correct event
        vm.expectEmit(true, false, false, true, address(_hook.test_store()));
        emit CleanTiers(address(_hook), beneficiary);
        vm.startPrank(beneficiary);
        _hook.test_store().cleanTiers(address(_hook));
        vm.stopPrank();
        _tiersListDump = _hook.test_store().ForTest_dumpTiersList(address(_hook));
        // check no of tiers
        assertEq(_tiersListDump.length, initialNumberOfTiers - numberOfTiersToRemove);
        // Check: the activer tiers are in the likned list
        assertTrue(_isIn(tiersRemaining, _tiersListDump));
        // Check: the linked list is only the active tiers
        assertTrue(_isIn(_tiersListDump, tiersRemaining));
    }

    function testJBTieredNFTRewardDelegate_tiersOf_emptyArrayIfNoInitializedTiers(uint256 _size) public {
        // Initialize with 0 tiers
        JB721TiersHook _hook = _initializeDelegateDefaultTiers(0);

        // Try to get _size tiers
        JB721Tier[] memory _intialTiers = _hook.STORE().tiersOf(address(_hook), new uint256[](0), false, 0, _size);

        // Check: Array of size 0?
        assertEq(_intialTiers.length, 0, "Length mismatch");
    }
}
