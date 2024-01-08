// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/juice-contracts-v4/src/interfaces/IJBDirectory.sol";
import "lib/juice-contracts-v4/src/interfaces/IJBRulesets.sol";
import "./../enums/JB721GovernanceType.sol";
import "./../interfaces/IJB721TokenUriResolver.sol";
import "./../interfaces/IJB721TiersHookStore.sol";
import "./JB721InitTiersConfig.sol";
import "./JB721TiersHookFlags.sol";

/// @custom:member name The NFT collection's name.
/// @custom:member symbol The NFT collection's symbol.
/// @custom:member rulesets The contract storing and managing project rulesets.
/// @custom:member baseUri The URI to use as a base for full NFT URIs.
/// @custom:member tokenUriResolver The contract responsible for resolving the URI for each NFT.
/// @custom:member contractUri The URI where this contract's metadata can be found.
/// @custom:member tiersConfig The NFT tiers and pricing config to launch the hook with.
/// @custom:member reserveBeneficiary The default reserved beneficiary for all tiers.
/// @custom:member store The contract to store and manage this hook's data.
/// @custom:member flags A set of boolean options to configure the hook with.
/// @custom:member governanceType The type of governance to use the NFTs for (onchain or not).
struct JBDeploy721TiersHookConfig {
    string name;
    string symbol;
    IJBRulesets rulesets;
    string baseUri;
    IJB721TokenUriResolver tokenUriResolver;
    string contractUri;
    JB721InitTiersConfig tiersConfig;
    address reserveBeneficiary;
    IJB721TiersHookStore store;
    JB721TiersHookFlags flags;
    JB721GovernanceType governanceType;
}
