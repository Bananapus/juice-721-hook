// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJB721TokenUriResolver} from "./IJB721TokenUriResolver.sol";
import {JB721TierConfig} from "./../structs/JB721TierConfig.sol";
import {JB721Tier} from "./../structs/JB721Tier.sol";
import {JB721TiersHookFlags} from "./../structs/JB721TiersHookFlags.sol";

interface IJB721TiersHookStore {
    event CleanTiers(address indexed nft, address caller);

    function totalSupplyOf(address nft) external view returns (uint256);

    function balanceOf(address nft, address owner) external view returns (uint256);

    function maxTierIdOf(address nft) external view returns (uint256);

    function tiersOf(
        address nft,
        uint256[] calldata categories,
        bool includeResolvedUri,
        uint256 startingSortIndex,
        uint256 size
    )
        external
        view
        returns (JB721Tier[] memory tiers);

    function tierOf(address nft, uint256 id, bool includeResolvedUri) external view returns (JB721Tier memory tier);

    function tierBalanceOf(address nft, address owner, uint256 tier) external view returns (uint256);

    function tierOfTokenId(
        address nft,
        uint256 tokenId,
        bool includeResolvedUri
    )
        external
        view
        returns (JB721Tier memory tier);

    function tierIdOfToken(uint256 tokenId) external pure returns (uint256);

    function encodedIPFSUriOf(address nft, uint256 tierId) external view returns (bytes32);

    function redemptionWeightOf(address nft, uint256[] memory tokenIds) external view returns (uint256 weight);

    function totalRedemptionWeight(address nft) external view returns (uint256 weight);

    function numberOfPendingReservesFor(address nft, uint256 tierId) external view returns (uint256);

    function numberOfReservesMintedFor(address nft, uint256 tierId) external view returns (uint256);

    function numberOfBurnedFor(address nft, uint256 tierId) external view returns (uint256);

    function isTierRemoved(address nft, uint256 tierId) external view returns (bool);

    function flagsOf(address nft) external view returns (JB721TiersHookFlags memory);

    function votingUnitsOf(address nft, address account) external view returns (uint256 units);

    function tierVotingUnitsOf(address nft, address account, uint256 tierId) external view returns (uint256 units);

    function defaultReserveBeneficiaryOf(address nft) external view returns (address);

    function reserveBeneficiaryOf(address nft, uint256 tierId) external view returns (address);

    function tokenUriResolverOf(address nft) external view returns (IJB721TokenUriResolver);

    function encodedTierIPFSUriOf(address nft, uint256 tokenId) external view returns (bytes32);

    function recordAddTiers(JB721TierConfig[] memory tierData) external returns (uint256[] memory tierIds);

    function recordMintReservesFor(uint256 tierId, uint256 count) external returns (uint256[] memory tokenIds);

    function recordBurn(uint256[] memory tokenIds) external;

    function recordMint(
        uint256 amount,
        uint16[] calldata tierIds,
        bool isManualMint
    )
        external
        returns (uint256[] memory tokenIds, uint256 leftoverAmount);

    function recordTransferForTier(uint256 tierId, address from, address to) external;

    function recordRemoveTierIds(uint256[] memory tierIds) external;

    function recordSetTokenUriResolver(IJB721TokenUriResolver resolver) external;

    function recordSetEncodedIPFSUriOf(uint256 tierId, bytes32 encodedIPFSUri) external;

    function recordFlags(JB721TiersHookFlags calldata flag) external;

    function cleanTiers(address nft) external;
}
