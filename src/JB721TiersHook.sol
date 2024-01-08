// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {mulDiv} from "lib/prb-math/src/Common.sol";
import {IJBPermissions} from "lib/juice-contracts-v4/src/interfaces/IJBPermissions.sol";
import {JBOwnable} from "lib/juice-ownable/src/JBOwnable.sol";
import {JBRulesetMetadataResolver} from "lib/juice-contracts-v4/src/libraries/JBRulesetMetadataResolver.sol";
import {IJBRulesets} from "lib/juice-contracts-v4/src/interfaces/IJBRulesets.sol";
import {IJBPrices} from "lib/juice-contracts-v4/src/interfaces/IJBPrices.sol";
import {IJBProjects} from "lib/juice-contracts-v4/src/interfaces/IJBProjects.sol";
import {IJBDirectory} from "lib/juice-contracts-v4/src/interfaces/IJBDirectory.sol";
import {JBBeforeRedeemRecordedContext} from "lib/juice-contracts-v4/src/structs/JBBeforeRedeemRecordedContext.sol";
import {JBAfterPayRecordedContext} from "lib/juice-contracts-v4/src/structs/JBAfterPayRecordedContext.sol";
import {JBRuleset} from "lib/juice-contracts-v4/src/structs/JBRuleset.sol";

import {JB721Hook} from "./abstract/JB721Hook.sol";
import {IJB721TiersHook} from "./interfaces/IJB721TiersHook.sol";
import {IJB721TokenUriResolver} from "./interfaces/IJB721TokenUriResolver.sol";
import {IJB721TiersHookStore} from "./interfaces/IJB721TiersHookStore.sol";
import {JB721PermissionIds} from "./libraries/JB721PermissionIds.sol";
import {JBIpfsDecoder} from "./libraries/JBIpfsDecoder.sol";
import {JB721TiersRulesetMetadataResolver} from "./libraries/JB721TiersRulesetMetadataResolver.sol";
import {JB721TierConfig} from "./structs/JB721TierConfig.sol";
import {JB721Tier} from "./structs/JB721Tier.sol";
import {JB721TiersHookFlags} from "./structs/JB721TiersHookFlags.sol";
import {JB721InitTiersConfig} from "./structs/JB721InitTiersConfig.sol";
import {JB721TiersMintReservesParams} from "./structs/JB721TiersMintReservesParams.sol";
import {JBMetadataResolver} from "lib/juice-contracts-v4/src/libraries/JBMetadataResolver.sol";

/// @title JB721TiersHook
/// @notice A Juicebox project can use this hook to sell tiered ERC-721 NFTs with different prices and metadata. When
/// the project is paid, the hook may mint NFTs to the payer, depending on the hook's setup, the amount paid, and
/// information specified by the payer. The project's owner can enable NFT redemptions through this hook, allowing
/// holders to burn their NFTs to reclaim funds from the project (in proportion to the NFT's price).
contract JB721TiersHook is JBOwnable, JB721Hook, IJB721TiersHook {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error OVERSPENDING();
    error MINT_RESERVE_NFTS_PAUSED();
    error TIER_TRANSFERS_PAUSED();

    //*********************************************************************//
    // --------------- public immutable stored properties ---------------- //
    //*********************************************************************//

    /// @notice The address of the original `JB721TiersHook`.
    /// @dev Used in `initialize(...)` to check if this is the original `JB721TiersHook`, and to revert initialization
    /// if it is.
    address public immutable override CODE_ORIGIN;

    //*********************************************************************//
    // --------------------- internal stored properties ------------------ //
    //*********************************************************************//

    /// @notice The first owner of each token ID, stored on first transfer out.
    /// @custom:param The token ID of the NFT to get the stored first owner of.
    mapping(uint256 tokenId => address) internal _firstOwnerOf;

    /// @notice Packed context for the pricing of this contract's tiers.
    /// @dev Packed into a uint256:
    /// - currency in bits 0-47 (48 bits),
    /// - pricing decimals in bits 48-95 (48 bits), and
    /// - prices contract in bits 96-255 (160 bits).
    uint256 internal _packedPricingContext;

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice The contract that stores and manages data for this contract's NFTs.
    IJB721TiersHookStore public override STORE;

    /// @notice The contract storing and managing project rulesets.
    IJBRulesets public override RULESETS;

    /// @notice If an address pays more than the price of the NFT they received, the extra amount is stored as credits
    /// which can be redeemed to mint NFTs.
    /// @custom:param addr The address to get the NFT credits balance of.
    /// @return The amount of credits the address has.
    mapping(address addr => uint256) public override payCreditsOf;

    /// @notice The base URI for the NFT `tokenUris`.
    string public override baseURI;

    /// @notice This contract's metadata URI.
    string public override contractURI;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice The first owner of an NFT.
    /// @dev This is generally the address which paid for the NFT.
    /// @param tokenId The token ID of the NFT to get the first owner of.
    /// @return The address of the NFT's first owner.
    function firstOwnerOf(uint256 tokenId) external view override returns (address) {
        // Get a reference to the first owner.
        address storedFirstOwner = _firstOwnerOf[tokenId];

        // If the stored first owner is set, return it.
        if (storedFirstOwner != address(0)) return storedFirstOwner;

        // Otherwise, the first owner must be the current owner.
        return _ownerOf(tokenId);
    }

    /// @notice Context for the pricing of this hook's tiers.
    /// @dev If the `prices` contract is the zero address, this contract only accepts payments in the `currency` token.
    /// @return currency The currency used for tier prices.
    /// @return decimals The amount of decimals being used in tier prices.
    /// @return prices The prices contract used to resolve the value of payments in currencies other than `currency`.
    function pricingContext() external view override returns (uint256 currency, uint256 decimals, IJBPrices prices) {
        // Get a reference to the packed pricing context.
        uint256 packed = _packedPricingContext;
        // currency in bits 0-47 (48 bits).
        currency = uint256(uint48(packed));
        // pricing decimals in bits 48-95 (48 bits).
        decimals = uint256(uint48(packed >> 48));
        // prices contract in bits 96-255 (160 bits).
        prices = IJBPrices(address(uint160(packed >> 96)));
    }

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice The total number of this hook's NFTs that an address holds (from all tiers).
    /// @param owner The address to check the balance of.
    /// @return balance The number of NFTs the address owns across this hook's tiers.
    function balanceOf(address owner) public view override returns (uint256 balance) {
        return STORE.balanceOf(address(this), owner);
    }

    /// @notice The metadata URI of the NFT with the specified token ID.
    /// @dev Defers to the `tokenUriResolver` if it is set. Otherwise, use the `tokenUri` corresponding with the NFT's
    /// tier.
    /// @param tokenId The token ID of the NFT to get the metadata URI of.
    /// @return The token URI from the `tokenUriResolver` if it is set. If it isn't set, the token URI for the NFT's
    /// tier.
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        // Get a reference to the `tokenUriResolver`.
        IJB721TokenUriResolver resolver = STORE.tokenUriResolverOf(address(this));

        // If a `tokenUriResolver` is set, use it to resolve the token URI.
        if (address(resolver) != address(0)) return resolver.tokenUriOf(address(this), tokenId);

        // Otherwise, return the token URI corresponding with the NFT's tier.
        return JBIpfsDecoder.decode(baseURI, STORE.encodedTierIPFSUriOf(address(this), tokenId));
    }

    /// @notice The combined redemption weight of the NFTs with the specified token IDs.
    /// @dev An NFT's redemption weight is its price.
    /// @dev To get their relative redemption weight, divide the result by the `totalRedemptionWeight(...)`.
    /// @param tokenIds The token IDs of the NFTs to get the cumulative redemption weight of.
    /// @return The redemption weight of the tokenIds.
    function redemptionWeightOf(
        uint256[] memory tokenIds,
        JBBeforeRedeemRecordedContext calldata
    )
        public
        view
        virtual
        override
        returns (uint256)
    {
        return STORE.redemptionWeightOf(address(this), tokenIds);
    }

    /// @notice The combined redemption weight of all outstanding NFTs.
    /// @dev An NFT's redemption weight is its price.
    /// @return The total redemption weight.
    function totalRedemptionWeight(JBBeforeRedeemRecordedContext calldata)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return STORE.totalRedemptionWeight(address(this));
    }

    /// @notice Indicates if this contract adheres to the specified interface.
    /// @dev See {IERC165-supportsInterface}.
    /// @param _interfaceId The ID of the interface to check for adherence to.
    function supportsInterface(bytes4 _interfaceId) public view override returns (bool) {
        return _interfaceId == type(IJB721TiersHook).interfaceId || super.supportsInterface(_interfaceId);
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param directory A directory of terminals and controllers for projects.
    /// @param permissions A contract storing permissions.
    constructor(
        IJBDirectory directory,
        IJBPermissions permissions
    )
        JBOwnable(directory.PROJECTS(), permissions)
        JB721Hook(directory)
    {
        CODE_ORIGIN = address(this);
    }

    /// @notice Initializes a cloned copy of the original `JB721Hook` contract.
    /// @param projectId The ID of the project this this hook is associated with.
    /// @param name The name of the NFT collection.
    /// @param symbol The symbol representing the NFT collection.
    /// @param rulesets A contract storing and managing project rulesets.
    /// @param baseUri The URI to use as a base for full NFT `tokenUri`s.
    /// @param tokenUriResolver An optional contract responsible for resolving the token URI for each NFT's token ID.
    /// @param contractUri A URI where this contract's metadata can be found.
    /// @param tiersConfig The NFT tiers and pricing context to initialize the hook with. The tiers must be sorted by
    /// price (from least to greatest).
    /// @param store The contract which stores the NFT's data.
    /// @param flags A set of additional options which dictate how the hook behaves.
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
        public
        override
    {
        // Stop re-initialization.
        if (address(STORE) != address(0)) revert();

        // Initialize the superclass.
        JB721Hook._initialize(projectId, name, symbol);

        RULESETS = rulesets;
        STORE = store;

        // Pack pricing context from the `tiersConfig`.
        uint256 packed;
        // pack the currency in bits 0-47 (48 bits).
        packed |= uint256(tiersConfig.currency);
        // pack the pricing decimals in bits 48-95 (48 bits).
        packed |= uint256(tiersConfig.decimals) << 48;
        // pack the prices contract in bits 96-255 (160 bits).
        packed |= uint256(uint160(address(tiersConfig.prices))) << 96;
        // Store the packed value.
        _packedPricingContext = packed;

        // Store the base URI if provided.
        if (bytes(baseUri).length != 0) baseURI = baseUri;

        // Set the contract URI if provided.
        if (bytes(contractUri).length != 0) contractURI = contractUri;

        // Set the token URI resolver if provided.
        if (tokenUriResolver != IJB721TokenUriResolver(address(0))) {
            store.recordSetTokenUriResolver(tokenUriResolver);
        }

        // Record the tiers in this hook's store.
        if (tiersConfig.tiers.length != 0) store.recordAddTiers(tiersConfig.tiers);

        // Set the flags if needed.
        if (
            flags.noNewTiersWithReserves || flags.noNewTiersWithVotes || flags.noNewTiersWithOwnerMinting
                || flags.preventOverspending
        ) store.recordFlags(flags);

        // Transfer ownership to the initializer.
        _transferOwnership(msg.sender);
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Manually mint NFTs from the provided tiers .
    /// @param tierIds The IDs of the tiers to mint from.
    /// @param beneficiary The address to mint to.
    /// @return tokenIds The IDs of the newly minted tokens.
    function mintFor(
        uint16[] calldata tierIds,
        address beneficiary
    )
        external
        override
        returns (uint256[] memory tokenIds)
    {
        // Enforce permissions.
        _requirePermissionFrom({account: owner(), projectId: projectId, permissionId: JB721PermissionIds.MINT});

        // Record the mint. The token IDs returned correspond to the tiers passed in.
        (tokenIds,) = STORE.recordMint(
            type(uint256).max, // force the mint.
            tierIds,
            true // manual mint.
        );

        // Keep a reference to the number of NFTs being minted.
        uint256 numberOfNfts = tierIds.length;

        // Keep a reference to the token ID being iterated upon.
        uint256 tokenId;

        for (uint256 i; i < numberOfNfts; i++) {
            // Set the token ID.
            tokenId = tokenIds[i];

            // Mint the NFT.
            _mint(beneficiary, tokenId);

            emit Mint(tokenId, tierIds[i], beneficiary, 0, msg.sender);
        }
    }

    /// @notice Mint pending reserved NFTs based on the provided information.
    /// @dev "Pending" means that the NFTs have been reserved, but have not been minted yet.
    /// @param reserveMintParams Contains information about how many reserved tokens to mint for each tier.
    function mintPendingReservesFor(JB721TiersMintReservesParams[] calldata reserveMintParams) external override {
        // Keep a reference to the number of tiers to mint reserves for.
        uint256 numberOfTiers = reserveMintParams.length;

        for (uint256 i; i < numberOfTiers; i++) {
            // Get a reference to the params being iterated upon.
            JB721TiersMintReservesParams memory params = reserveMintParams[i];

            // Mint pending reserved NFTs from the tier.
            mintPendingReservesFor(params.tierId, params.count);
        }
    }

    /// @notice Add or delete tiers.
    /// @dev Only the contract's owner or an operator with the `ADJUST_TIERS` permission from the owner can adjust the
    /// tiers.
    /// @dev Any added tiers must adhere to this hook's `JB721TiersHookFlags`.
    /// @param tiersToAdd The tiers to add, as an array of `JB721TierConfig` structs`.
    /// @param tierIdsToRemove The tiers to remove, as an array of tier IDs.
    function adjustTiers(JB721TierConfig[] calldata tiersToAdd, uint256[] calldata tierIdsToRemove) external override {
        // Enforce permissions.
        _requirePermissionFrom({account: owner(), projectId: projectId, permissionId: JB721PermissionIds.ADJUST_TIERS});

        // Get a reference to the number of tiers being added.
        uint256 numberOfTiersToAdd = tiersToAdd.length;

        // Get a reference to the number of tiers being removed.
        uint256 numberOfTiersToRemove = tierIdsToRemove.length;

        // Remove the tiers.
        if (numberOfTiersToRemove != 0) {
            // Record the removed tiers.
            STORE.recordRemoveTierIds(tierIdsToRemove);

            // Emit events for each removed tier.
            for (uint256 i; i < numberOfTiersToRemove;  i++) {
                emit RemoveTier(tierIdsToRemove[i], msg.sender);
            }
        }

        // Add the tiers.
        if (numberOfTiersToAdd != 0) {
            // Record the added tiers in the store.
            uint256[] memory tierIdsAdded = STORE.recordAddTiers(tiersToAdd);

            // Emit events for each added tier.
            for (uint256 i; i < numberOfTiersToAdd; i++) {
                emit AddTier(tierIdsAdded[i], tiersToAdd[i], msg.sender);
            }
        }
    }

    /// @notice Update this hook's URI metadata properties.
    /// @dev Only this contract's owner can set the metadata.
    /// @param baseUri The new base URI.
    /// @param contractUri The new contract URI.
    /// @param tokenUriResolver The new URI resolver.
    /// @param encodedIPFSTUriTierId The ID of the tier to set the encoded IPFS URI of.
    /// @param encodedIPFSUri The encoded IPFS URI to set.
    function setMetadata(
        string calldata baseUri,
        string calldata contractUri,
        IJB721TokenUriResolver tokenUriResolver,
        uint256 encodedIPFSTUriTierId,
        bytes32 encodedIPFSUri
    )
        external
        override
    {
        // Enforce permissions.
        _requirePermissionFrom({
            account: owner(),
            projectId: projectId,
            permissionId: JB721PermissionIds.UPDATE_METADATA
        });

        if (bytes(baseUri).length != 0) {
            // Store the new base URI.
            baseURI = baseUri;
            emit SetBaseUri(baseUri, msg.sender);
        }
        if (bytes(contractUri).length != 0) {
            // Store the new contract URI.
            contractURI = contractUri;
            emit SetContractUri(contractUri, msg.sender);
        }
        if (tokenUriResolver != IJB721TokenUriResolver(address(this))) {
            // Store the new URI resolver.
            STORE.recordSetTokenUriResolver(tokenUriResolver);

            emit SetTokenUriResolver(tokenUriResolver, msg.sender);
        }
        if (encodedIPFSTUriTierId != 0 && encodedIPFSUri != bytes32(0)) {
            // Store the new encoded IPFS URI.
            STORE.recordSetEncodedIPFSUriOf(encodedIPFSTUriTierId, encodedIPFSUri);

            emit SetEncodedIPFSUri(encodedIPFSTUriTierId, encodedIPFSUri, msg.sender);
        }
    }

    //*********************************************************************//
    // ----------------------- public transactions ----------------------- //
    //*********************************************************************//

    /// @notice Mint reserved pending reserved NFTs within the provided tier.
    /// @dev "Pending" means that the NFTs have been reserved, but have not been minted yet.
    /// @param tierId The ID of the tier to mint reserved NFTs from.
    /// @param count The number of reserved NFTs to mint.
    function mintPendingReservesFor(uint256 tierId, uint256 count) public override {
        // Get a reference to the project's current ruleset.
        JBRuleset memory ruleset = RULESETS.currentOf(projectId);

        // Pending reserve mints must not be paused.
        if (JB721TiersRulesetMetadataResolver.mintPendingReservesPaused((JBRulesetMetadataResolver.metadata(ruleset))))
        {
            revert MINT_RESERVE_NFTS_PAUSED();
        }

        // Record the reserved mint for the tier.
        uint256[] memory tokenIds = STORE.recordMintReservesFor(tierId, count);

        // Keep a reference to the beneficiary.
        address reserveBeneficiary = STORE.reserveBeneficiaryOf(address(this), tierId);

        // Keep a reference to the token ID being iterated upon.
        uint256 tokenId;

        for (uint256 i; i < count; i++) {
            // Set the token ID.
            tokenId = tokenIds[i];

            // Mint the NFT.
            _mint(reserveBeneficiary, tokenId);

            emit MintReservedNft(tokenId, tierId, reserveBeneficiary, msg.sender);
        }
    }

    //*********************************************************************//
    // ------------------------ internal functions ----------------------- //
    //*********************************************************************//

    /// @notice Process a payment, minting NFTs and updating credits as necessary.
    /// @param context Payment context provided by the terminal after it has recorded the payment in the terminal store.
    function _processPayment(JBAfterPayRecordedContext calldata context) internal virtual override {
        // Normalize the payment value based on the pricing context.
        uint256 value;

        {
            uint256 packed = _packedPricingContext;
            // pricing currency in bits 0-47 (48 bits).
            uint256 pricingCurrency = uint256(uint48(packed));
            if (context.amount.currency == pricingCurrency) {
                value = context.amount.value;
            } else {
                // prices in bits 96-255 (160 bits).
                IJBPrices prices = IJBPrices(address(uint160(packed >> 96)));
                if (prices != IJBPrices(address(0))) {
                    // pricing decimals in bits 48-95 (48 bits).
                    uint256 pricingDecimals = uint256(uint48(packed >> 48));
                    value = mulDiv(
                        context.amount.value,
                        10 ** pricingDecimals,
                        prices.pricePerUnitOf({
                            projectId: projectId,
                            pricingCurrency: context.amount.currency,
                            unitCurrency: pricingCurrency,
                            decimals: context.amount.decimals
                        })
                    );
                } else {
                    return;
                }
            }
        }

        // Keep a reference to the number of NFT credits the beneficiary already has.
        uint256 payCredits = payCreditsOf[context.beneficiary];

        // Set the leftover amount as the initial value.
        uint256 leftoverAmount = value;

        // If the payer is the beneficiary, combine their NFT credits with the amount paid.
        uint256 unusedPayCredits;
        if (context.payer == context.beneficiary) {
            unchecked {
                leftoverAmount += payCredits;
            }
        } else {
            // Otherwise, the payer's NFT credits won't be used, and we keep track of the unused credits.
            unusedPayCredits = payCredits;
        }

        // Keep a reference to the boolean indicating whether paying more than the price of the NFTs being minted is
        // allowed. Defaults to false.
        bool allowOverspending;

        // The metadata ID is the first 4 bytes of this contract's address.
        bytes4 metadataId = bytes4(bytes20(address(this)));

        // Resolve the metadata.
        (bool found, bytes memory metadata) = JBMetadataResolver.getDataFor(metadataId, context.payerMetadata);

        if (found) {
            // Keep a reference to the IDs of the tier be to minted.
            uint16[] memory tierIdsToMint;

            // Decode the metadata.
            (allowOverspending, tierIdsToMint) = abi.decode(metadata, (bool, uint16[]));

            // Make sure overspending is allowed if requested.
            if (allowOverspending && STORE.flagsOf(address(this)).preventOverspending) {
                allowOverspending = false;
            }

            // Mint NFTs from the tiers as specified.
            if (tierIdsToMint.length != 0) {
                leftoverAmount = _mintAll(leftoverAmount, tierIdsToMint, context.beneficiary);
            }
        } else if (!STORE.flagsOf(address(this)).preventOverspending) {
            allowOverspending = true;
        }

        // If overspending is allowed and there are leftover funds, add those funds to the beneficiary's NFT credits.
        if (leftoverAmount != 0) {
            // If overspending isn't allowed, revert.
            if (!allowOverspending) revert OVERSPENDING();

            // Increment the leftover amount.
            unchecked {
                // Keep a reference to the amount of new NFT credits.
                uint256 newpayCredits = leftoverAmount + unusedPayCredits;

                // Emit the change in NFT credits.
                if (newpayCredits > payCredits) {
                    emit AddPayCredits(newpayCredits - payCredits, newpayCredits, context.beneficiary, msg.sender);
                } else if (payCredits > newpayCredits) {
                    emit UsePayCredits(payCredits - newpayCredits, newpayCredits, context.beneficiary, msg.sender);
                }

                // Store the new NFT credits for the beneficiary.
                payCreditsOf[context.beneficiary] = newpayCredits;
            }
            // Otherwise, reset their NFT credits.
        } else if (payCredits != unusedPayCredits) {
            // Emit the change in NFT credits.
            emit UsePayCredits(payCredits - unusedPayCredits, unusedPayCredits, context.beneficiary, msg.sender);

            // Store the new NFT credits.
            payCreditsOf[context.beneficiary] = unusedPayCredits;
        }
    }

    /// @notice A function which gets called after NFTs have been redeemed and recorded by the terminal.
    /// @param tokenIds The token IDs of the NFTs that were burned.
    function _didBurn(uint256[] memory tokenIds) internal virtual override {
        // Add to burned counter.
        STORE.recordBurn(tokenIds);
    }

    /// @notice Mints one NFT from each of the specified tiers for the beneficiary.
    /// @dev The same tier can be specified more than once.
    /// @param amount The amount to base the mints on. The total price of the NFTs being minted cannot be larger than
    /// this amount.
    /// @param mintTierIds An array of NFT tier IDs to be minted.
    /// @param beneficiary The address receiving the newly minted NFTs.
    /// @return leftoverAmount The `amount` leftover after minting.
    function _mintAll(
        uint256 amount,
        uint16[] memory mintTierIds,
        address beneficiary
    )
        internal
        returns (uint256 leftoverAmount)
    {
        // Keep a reference to the NFT token IDs.
        uint256[] memory tokenIds;

        // Record the NFT mints. The token IDs returned correspond to the tier IDs passed in.
        (tokenIds, leftoverAmount) = STORE.recordMint(
            amount,
            mintTierIds,
            false // Not a manual mint
        );

        // Get a reference to the number of NFTs being minted.
        uint256 mintsLength = tokenIds.length;

        // Keep a reference to the token ID being iterated on.
        uint256 tokenId;

        // Loop through each token ID and mint the corresponding NFT.
        for (uint256 i; i < mintsLength; i++) {
            // Get a reference to the token ID being iterated on.
            tokenId = tokenIds[i];

            // Mint the NFT.
            _mint(beneficiary, tokenId);

            emit Mint(tokenId, mintTierIds[i], beneficiary, amount, msg.sender);
        }
    }

    /// @notice Before transferring an NFT, register its first owner (if necessary).
    /// @param to The address the NFT is being transferred to.
    /// @param tokenId The token ID of the NFT being transferred.
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address from) {
        // Get a reference to the tier.
        JB721Tier memory tier = STORE.tierOfTokenId(address(this), tokenId, false);

        // Record the transfers and keep a reference to where the token is coming from.
        from = super._update(to, tokenId, auth);

        // Transfers must not be paused (when not minting or burning).
        if (from != address(0)) {
            // If transfers are pausable, check if they're paused.
            if (tier.transfersPausable) {
                // Get a reference to the project's current ruleset.
                JBRuleset memory ruleset = RULESETS.currentOf(projectId);

                // If transfers are paused and the NFT isn't being transferred to the zero address, revert.
                if (
                    to != address(0)
                        && JB721TiersRulesetMetadataResolver.transfersPaused((JBRulesetMetadataResolver.metadata(ruleset)))
                ) revert TIER_TRANSFERS_PAUSED();
            }

            // If the token isn't already associated with a first owner, store the sender as the first owner.
            if (_firstOwnerOf[tokenId] == address(0)) _firstOwnerOf[tokenId] = from;
        }

        // Record the transfer.
        STORE.recordTransferForTier(tier.id, from, to);

        // Handle any other accounting (e.g. transfer voting units in the `JBGoverned721TiersHook`).
        _afterTokenTransferAccounting(from, to, tokenId, tier);
    }

    /// @notice After transferring an NFT, handle any other accounting. This lets us use `tier` without fetching it
    /// again.
    /// @dev This function is used to transfer voting units in the `JBGoverned721TiersHook`.
    /// @param from The address the NFT is being transferred from.
    /// @param to The address the NFT is being transferred to.
    /// @param tokenId The token ID of the NFT being transferred.
    /// @param tier The NFT's tier as a `JB721Tier` struct.
    function _afterTokenTransferAccounting(
        address from,
        address to,
        uint256 tokenId,
        JB721Tier memory tier
    )
        internal
        virtual
    {
        from; // Prevents unused var compiler and natspec complaints.
        to;
        tokenId;
        tier;
    }
}
