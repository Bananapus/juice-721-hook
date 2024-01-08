// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {mulDiv} from "lib/prb-math/src/Common.sol";
import {IERC165} from "lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {IERC2981} from "lib/openzeppelin-contracts/contracts/interfaces/IERC2981.sol";
import {IJBRulesetDataHook} from "lib/juice-contracts-v4/src/interfaces/IJBRulesetDataHook.sol";
import {IJBDirectory} from "lib/juice-contracts-v4/src/interfaces/IJBDirectory.sol";
import {IJBPayHook} from "lib/juice-contracts-v4/src/interfaces/IJBPayHook.sol";
import {IJBRedeemHook} from "lib/juice-contracts-v4/src/interfaces/IJBRedeemHook.sol";
import {IJBTerminal} from "lib/juice-contracts-v4/src/interfaces/terminal/IJBTerminal.sol";
import {JBConstants} from "lib/juice-contracts-v4/src/libraries/JBConstants.sol";
import {JBBeforePayRecordedContext} from "lib/juice-contracts-v4/src/structs/JBBeforePayRecordedContext.sol";
import {JBAfterPayRecordedContext} from "lib/juice-contracts-v4/src/structs/JBAfterPayRecordedContext.sol";
import {JBAfterRedeemRecordedContext} from "lib/juice-contracts-v4/src/structs/JBAfterRedeemRecordedContext.sol";
import {JBBeforeRedeemRecordedContext} from "lib/juice-contracts-v4/src/structs/JBBeforeRedeemRecordedContext.sol";
import {JBPayHookSpecification} from "lib/juice-contracts-v4/src/structs/JBPayHookSpecification.sol";
import {JBRedeemHookSpecification} from "lib/juice-contracts-v4/src/structs/JBRedeemHookSpecification.sol";
import {JBMetadataResolver} from "lib/juice-contracts-v4/src/libraries/JBMetadataResolver.sol";

import {ERC721} from "./ERC721.sol";
import {IJB721Hook} from "../interfaces/IJB721Hook.sol";

/// @title JB721Hook
/// @notice When a project which uses this hook is paid, this hook may mint NFTs to the payer, depending on this hook's
/// setup, the amount paid, and information specified by the payer. The project's owner can enable NFT redemptions
/// through this hook, allowing the NFT holders to burn their NFTs to reclaim funds from the project (in proportion to
/// the NFT's price).
abstract contract JB721Hook is ERC721, IJB721Hook, IJBRulesetDataHook, IJBPayHook, IJBRedeemHook {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error INVALID_PAY_EVENT();
    error INVALID_REDEEM_EVENT();
    error UNAUTHORIZED_TOKEN(uint256 tokenId);
    error UNEXPECTED_TOKEN_REDEEMED();

    //*********************************************************************//
    // --------------- public immutable stored properties ---------------- //
    //*********************************************************************//

    /// @notice The directory of terminals and controllers for projects.
    IJBDirectory public immutable override DIRECTORY;

    //*********************************************************************//
    // -------------------- public stored properties --------------------- //
    //*********************************************************************//

    /// @notice The ID of the project that this contract is associated with.
    uint256 public override projectId;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice The data calculated before a payment is recorded in the terminal store. This data is provided to the
    /// terminal's `pay(...)` transaction.
    /// @dev Sets this contract as the pay hook. Part of `IJBRulesetDataHook`.
    /// @param context The payment context passed to this contract by the `pay(...)` function.
    /// @return weight The new `weight` to use, overriding the ruleset's `weight`.
    /// @return hookSpecifications The amount and data to send to pay hooks (this contract) instead of adding to the
    /// terminal's balance.
    function beforePayRecordedWith(JBBeforePayRecordedContext calldata context)
        public
        view
        virtual
        override
        returns (uint256 weight, JBPayHookSpecification[] memory hookSpecifications)
    {
        // Forward the received weight and memo, and use this contract as the only pay hook.
        weight = context.weight;
        hookSpecifications = new JBPayHookSpecification[](1);
        hookSpecifications[0] = JBPayHookSpecification(this, 0, bytes(""));
    }

    /// @notice The data calculated before a redemption is recorded in the terminal store. This data is provided to the
    /// terminal's `redeemTokensOf(...)` transaction.
    /// @dev Sets this contract as the redeem hook. Part of `IJBRulesetDataHook`.
    /// @dev This function is used for NFT redemptions, and will only be called if the project's ruleset has
    /// `useDataHookForRedeem` set to `true`.
    /// @param context The redemption context passed to this contract by the `redeemTokensOf(...)` function.
    /// @return reclaimAmount Amount to be reclaimed, overriding the terminal's logic.
    /// @return hookSpecifications The amount and data to send to redeem hooks (this contract) instead of returning to
    /// the beneficiary.
    function beforeRedeemRecordedWith(JBBeforeRedeemRecordedContext calldata context)
        public
        view
        virtual
        override
        returns (uint256 reclaimAmount, JBRedeemHookSpecification[] memory hookSpecifications)
    {
        // Make sure (fungible) project tokens aren't also being redeemed.
        if (context.redeemCount > 0) revert UNEXPECTED_TOKEN_REDEEMED();

        // The metadata ID is the first 4 bytes of this contract's address.
        bytes4 metadataId = bytes4(bytes20(address(this)));

        // Fetch the redeem hook metadata using the corresponding metadata ID.
        (bool found, bytes memory metadata) = JBMetadataResolver.getDataFor(metadataId, context.metadata);

        // Use this contract as the only redeem hook.
        hookSpecifications = new JBRedeemHookSpecification[](1);
        hookSpecifications[0] = JBRedeemHookSpecification(this, 0, bytes(""));

        uint256[] memory decodedTokenIds;

        // Decode the metadata.
        if (found) decodedTokenIds = abi.decode(metadata, (uint256[]));

        // Get a reference to the redemption weight of the provided tokens.
        uint256 redemptionWeight = redemptionWeightOf(decodedTokenIds, context);

        // Get a reference to the total redemption weight.
        uint256 total = totalRedemptionWeight(context);

        // Get a reference to the linear proportion that the provided tokens constitute (out of the total redemption
        // weight).
        uint256 base = mulDiv(context.surplus, redemptionWeight, total);

        // These conditions are all part of the same curve. Edge conditions are separated because fewer operation are
        // necessary.
        if (context.redemptionRate == JBConstants.MAX_REDEMPTION_RATE) {
            return (base, hookSpecifications);
        }

        // Return the weighted surplus, and this contract as the redeem hook (so that the tokens can be burned).
        return (
            mulDiv(
                base,
                context.redemptionRate
                    + mulDiv(redemptionWeight, JBConstants.MAX_REDEMPTION_RATE - context.redemptionRate, total),
                JBConstants.MAX_REDEMPTION_RATE
                ),
            hookSpecifications
        );
    }

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice Returns the cumulative redemption weight of the specified token IDs relative to the
    /// `totalRedemptionWeight`.
    /// @param tokenIds The NFT token IDs to calculate the cumulative redemption weight of.
    /// @param context The redemption context passed to this contract by the `redeemTokensOf(...)` function.
    /// @return The cumulative redemption weight of the specified token IDs.
    function redemptionWeightOf(
        uint256[] memory tokenIds,
        JBBeforeRedeemRecordedContext calldata context
    )
        public
        view
        virtual
        returns (uint256)
    {
        tokenIds; // Prevents unused var compiler and natspec complaints.
        context; // Prevents unused var compiler and natspec complaints.
        return 0;
    }

    /// @notice Calculates the cumulative redemption weight of all NFT token IDs.
    /// @param context The redemption context passed to this contract by the `redeemTokensOf(...)` function.
    /// @return The total cumulative redemption weight of all NFT token IDs.
    function totalRedemptionWeight(JBBeforeRedeemRecordedContext calldata context)
        public
        view
        virtual
        returns (uint256)
    {
        context; // Prevents unused var compiler and natspec complaints.
        return 0;
    }

    /// @notice Indicates if this contract adheres to the specified interface.
    /// @dev See {IERC165-supportsInterface}.
    /// @param _interfaceId The ID of the interface to check for adherence to.
    function supportsInterface(bytes4 _interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return _interfaceId == type(IJB721Hook).interfaceId || _interfaceId == type(IJBRulesetDataHook).interfaceId
            || _interfaceId == type(IJBPayHook).interfaceId || _interfaceId == type(IJBRedeemHook).interfaceId
            || _interfaceId == type(IERC2981).interfaceId || super.supportsInterface(_interfaceId);
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param directory A directory of terminals and controllers for projects.
    constructor(IJBDirectory directory) {
        DIRECTORY = directory;
    }

    /// @notice Initializes the contract by associating it with a project and adding ERC721 details.
    /// @param _projectId The ID of the project that this contract is associated with.
    /// @param name The name of the NFT collection.
    /// @param symbol The symbol representing the NFT collection.
    function _initialize(uint256 _projectId, string memory name, string memory symbol) internal {
        ERC721._initialize(name, symbol);
        projectId = _projectId;
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Mints one or more NFTs to the `context.benficiary` upon payment if conditions are met. Part of
    /// `IJBPayHook`.
    /// @dev Reverts if the calling contract is not one of the project's terminals.
    /// @param context The payment context passed in by the terminal.
    function afterPayRecordedWith(JBAfterPayRecordedContext calldata context) external payable virtual override {
        uint256 _projectId = projectId;

        // Make sure the caller is a terminal of the project, and that the call is being made on behalf of an
        // interaction with the correct project.
        if (
            msg.value != 0 || !DIRECTORY.isTerminalOf(_projectId, IJBTerminal(msg.sender))
                || context.projectId != _projectId
        ) revert INVALID_PAY_EVENT();

        // Process the payment.
        _processPayment(context);
    }

    /// @notice Burns the specified NFTs upon token holder redemption, reclaiming funds from the project's balance for
    /// `context.beneficiary`. Part of `IJBRedeemHook`.
    /// @dev Reverts if the calling contract is not one of the project's terminals.
    /// @param context The redemption context passed in by the terminal.
    function afterRedeemRecordedWith(JBAfterRedeemRecordedContext calldata context) external payable virtual override {
        // Make sure the caller is a terminal of the project, and that the call is being made on behalf of an
        // interaction with the correct project.
        if (
            msg.value != 0 || !DIRECTORY.isTerminalOf(projectId, IJBTerminal(msg.sender))
                || context.projectId != projectId
        ) revert INVALID_REDEEM_EVENT();

        // The metadata ID is the first 4 bytes of this contract's address.
        bytes4 metadataId = bytes4(bytes20(address(this)));

        // Fetch the redeem hook metadata using the corresponding metadata ID.
        (bool found, bytes memory metadata) = JBMetadataResolver.getDataFor(metadataId, context.redeemerMetadata);

        uint256[] memory decodedTokenIds;

        // Decode the metadata.
        if (found) decodedTokenIds = abi.decode(metadata, (uint256[]));

        // Get a reference to the number of NFT token IDs to check the owner of.
        uint256 numberOfTokenIds = decodedTokenIds.length;

        // Keep a reference to the NFT token ID being iterated upon.
        uint256 tokenId;

        // Iterate through the NFTs, burning them if the owner is correct.
        for (uint256 i; i < numberOfTokenIds; i++) {
            // Set the current NFT's token ID.
            tokenId = decodedTokenIds[i];

            // Make sure the token's owner is correct.
            if (_ownerOf(tokenId) != context.holder) revert UNAUTHORIZED_TOKEN(tokenId);

            // Burn the token.
            _burn(tokenId);
        }

        // Call the hook.
        _didBurn(decodedTokenIds);
    }

    //*********************************************************************//
    // ---------------------- internal transactions ---------------------- //
    //*********************************************************************//

    /// @notice Process a received payment.
    /// @param context The payment context passed in by the terminal.
    function _processPayment(JBAfterPayRecordedContext calldata context) internal virtual {
        context; // Prevents unused var compiler and natspec complaints.
    }

    /// @notice Executes after NFTs have been burned via redemption.
    /// @param tokenIds The token IDs of the NFTs that were burned.
    function _didBurn(uint256[] memory tokenIds) internal virtual {
        tokenIds;
    }
}
