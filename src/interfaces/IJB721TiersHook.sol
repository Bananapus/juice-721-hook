// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBDirectory} from "lib/juice-contracts-v4/src/interfaces/IJBDirectory.sol";
import {IJBRulesets} from "lib/juice-contracts-v4/src/interfaces/IJBRulesets.sol";
import {IJBPrices} from "lib/juice-contracts-v4/src/interfaces/IJBPrices.sol";

import {IJB721Hook} from "./IJB721Hook.sol";
import {IJB721TokenUriResolver} from "./IJB721TokenUriResolver.sol";
import {IJB721TiersHookStore} from "./IJB721TiersHookStore.sol";
import {JB721InitTiersConfig} from "./../structs/JB721InitTiersConfig.sol";
import {JB721TierConfig} from "./../structs/JB721TierConfig.sol";
import {JB721TiersHookFlags} from "./../structs/JB721TiersHookFlags.sol";
import {JB721TiersMintReservesParams} from "./../structs/JB721TiersMintReservesParams.sol";

interface IJB721TiersHook is IJB721Hook {
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

    event SetEncodedIPFSUri(uint256 indexed tierId, bytes32 encodedIPFSUri, address caller);

    event SetBaseUri(string indexed baseUri, address caller);

    event SetContractUri(string indexed contractUri, address caller);

    event SetTokenUriResolver(IJB721TokenUriResolver indexed newResolver, address caller);

    event AddPayCredits(
        uint256 indexed amount, uint256 indexed newTotalCredits, address indexed account, address caller
    );

    event UsePayCredits(
        uint256 indexed amount, uint256 indexed newTotalCredits, address indexed account, address caller
    );

    function CODE_ORIGIN() external view returns (address);

    function STORE() external view returns (IJB721TiersHookStore);

    function RULESETS() external view returns (IJBRulesets);

    function pricingContext() external view returns (uint256, uint256, IJBPrices);

    function payCreditsOf(address addr) external view returns (uint256);

    function firstOwnerOf(uint256 tokenId) external view returns (address);

    function baseURI() external view returns (string memory);

    function contractURI() external view returns (string memory);

    function adjustTiers(JB721TierConfig[] memory tierDataToAdd, uint256[] memory tierIdsToRemove) external;

    function mintPendingReservesFor(JB721TiersMintReservesParams[] memory reserveMintParams) external;

    function mintPendingReservesFor(uint256 tierId, uint256 count) external;

    function mintFor(uint16[] calldata tierIds, address beneficiary) external returns (uint256[] memory tokenIds);

    function setMetadata(
        string memory baseUri,
        string calldata contractMetadataUri,
        IJB721TokenUriResolver tokenUriResolver,
        uint256 encodedIPFSUriTierId,
        bytes32 encodedIPFSUri
    )
        external;

    function initialize(
        uint256 projectId,
        string memory name,
        string memory symbol,
        IJBRulesets rulesets,
        string memory baseUri,
        IJB721TokenUriResolver tokenUriResolver,
        string memory contractUri,
        JB721InitTiersConfig memory tiersConfig,
        IJB721TiersHookStore store,
        JB721TiersHookFlags memory flags
    )
        external;
}
