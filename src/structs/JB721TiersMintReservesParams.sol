// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @custom:member tierId The ID of the tier to mint from.
/// @custom:member count The number of NFTs to mint from that tier.
struct JB721TiersMintReservesParams {
    uint256 tierId;
    uint256 count;
}
