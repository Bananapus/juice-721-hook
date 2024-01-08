// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "src/interfaces/IJB721TiersHook.sol";

import "src/JB721TiersHook.sol";
import "src/JB721TiersHookStore.sol";

import "src/structs/JBBitmapWord.sol";

import "lib/juice-contracts-v4/src/structs/JBRulesetMetadata.sol";
import "lib/juice-contracts-v4/src/interfaces/IJBPermissioned.sol";
import {MetadataResolverHelper} from "lib/juice-contracts-v4/test/helpers/MetadataResolverHelper.sol";

import "lib/juice-contracts-v4/src/libraries/JBConstants.sol";

import "./UnitTestSetup.sol"; // Only used to get the `PAY_HOOK_ID` and `REDEEM_HOOK_ID` constants.

interface IJB721TiersHookStore_ForTest is IJB721TiersHookStore {
    function ForTest_dumpTiersList(address nft) external view returns (JB721Tier[] memory tiers);
    function ForTest_setTier(address hook, uint256 index, JBStored721Tier calldata newTier) external;
    function ForTest_setBalanceOf(address hook, address holder, uint256 tier, uint256 balance) external;
    function ForTest_setReservesMintedFor(address hook, uint256 tier, uint256 amount) external;
    function ForTest_setIsTierRemoved(address hook, uint256 tokenId) external;
    function ForTest_packBools(
        bool allowOwnerMint,
        bool transfersPausable,
        bool useVotingUnits
    )
        external
        returns (uint8);
}

contract ForTest_JB721TiersHook is JB721TiersHook {
    IJB721TiersHookStore_ForTest public test_store;
    MetadataResolverHelper metadataHelper;

    uint256 constant SURPLUS = 10e18;
    uint256 constant REDEMPTION_RATE = JBConstants.MAX_RESERVED_RATE; // 40%

    constructor(
        uint256 projectId,
        IJBDirectory directory,
        string memory name,
        string memory symbol,
        IJBRulesets rulesets,
        string memory baseUri,
        IJB721TokenUriResolver tokenUriResolver,
        string memory contractUri,
        JB721TierConfig[] memory tiers,
        IJB721TiersHookStore _test_store, // TODO: rename?
        JB721TiersHookFlags memory flags
    )
        // The directory is also `IJBPermissioned`.
        JB721TiersHook(directory, IJBPermissioned(address(directory)).PERMISSIONS())
    {
        // Disable the safety check to not allow initializing the original contract
        CODE_ORIGIN = address(0);
        JB721TiersHook.initialize(
            projectId,
            name,
            symbol,
            rulesets,
            baseUri,
            tokenUriResolver,
            contractUri,
            JB721InitTiersConfig({
                tiers: tiers,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
                decimals: 18,
                prices: IJBPrices(address(0))
            }),
            _test_store,
            flags
        );
        test_store = IJB721TiersHookStore_ForTest(address(_test_store));

        metadataHelper = new MetadataResolverHelper();
    }

    function ForTest_setOwnerOf(uint256 tokenId, address owner) public {
        _owners[tokenId] = owner;
    }
}

contract ForTest_JB721TiersHookStore is JB721TiersHookStore, IJB721TiersHookStore_ForTest {
    using JBBitmap for mapping(uint256 => uint256);
    using JBBitmap for JBBitmapWord;

    function ForTest_dumpTiersList(address nft) public view override returns (JB721Tier[] memory tiers) {
        // Keep a reference to the max tier ID.
        uint256 maxTierId = maxTierIdOf[nft];
        // Initialize an array with the appropriate length.
        tiers = new JB721Tier[](maxTierId);
        // Count the number of included tiers.
        uint256 numberOfIncludedTiers;
        // Get a reference to the sorted index being iterated on, starting with the first one.
        uint256 currentSortIndex = _firstSortedTierIdOf(nft, 0);
        // Keep a reference to the tier being iterated on.
        JBStored721Tier memory storedTier;
        // Make the sorted array.
        while (currentSortIndex != 0 && numberOfIncludedTiers < maxTierId) {
            storedTier = _storedTierOf[nft][currentSortIndex];

            // Unpack stored tier
            (bool allowOwnerMint, bool transfersPausable,) = _unpackBools(storedTier.packedBools);

            // Add the tier to the array being returned.
            tiers[numberOfIncludedTiers++] = JB721Tier({
                id: currentSortIndex,
                price: storedTier.price,
                remainingSupply: storedTier.remainingSupply,
                initialSupply: storedTier.initialSupply,
                votingUnits: storedTier.votingUnits,
                reserveFrequency: storedTier.reserveFrequency,
                reserveBeneficiary: reserveBeneficiaryOf(nft, currentSortIndex),
                encodedIPFSUri: encodedIPFSUriOf[nft][currentSortIndex],
                category: storedTier.category,
                allowOwnerMint: allowOwnerMint,
                transfersPausable: transfersPausable,
                resolvedUri: ""
            });
            // Set the next sort index.
            currentSortIndex = _nextSortedTierIdOf(nft, currentSortIndex, maxTierId);
        }
        // Drop the empty tiers at the end of the array.
        // The array's size is bsaed on `maxTierIdOf`, which *might* exceed the actual number of tiers.
        for (uint256 i = tiers.length - 1; i >= 0; i--) {
            if (tiers[i].id == 0) {
                assembly ("memory-safe") {
                    mstore(tiers, sub(mload(tiers), 1))
                }
            } else {
                break;
            }
        }
    }

    function ForTest_setTier(address hook, uint256 index, JBStored721Tier calldata newTier) public override {
        _storedTierOf[address(hook)][index] = newTier;
    }

    function ForTest_setBalanceOf(address hook, address holder, uint256 tier, uint256 balance) public override {
        tierBalanceOf[address(hook)][holder][tier] = balance;
    }

    function ForTest_setReservesMintedFor(address hook, uint256 tier, uint256 amount) public override {
        numberOfReservesMintedFor[address(hook)][tier] = amount;
    }

    function ForTest_setIsTierRemoved(address hook, uint256 tokenId) public override {
        _removedTiersBitmapWordOf[hook].removeTier(tokenId);
    }

    function ForTest_packBools(
        bool allowOwnerMint,
        bool transfersPausable,
        bool useVotingUnits
    )
        public
        pure
        returns (uint8)
    {
        return _packBools(allowOwnerMint, transfersPausable, useVotingUnits);
    }

    function ForTest_unpackBools(uint8 packed) public pure returns (bool, bool, bool) {
        return _unpackBools(packed);
    }
}
