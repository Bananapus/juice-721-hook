// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Votes} from "lib/openzeppelin-contracts/contracts/governance/utils/Votes.sol";
import {EIP712} from "lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import {IJBDirectory} from "lib/juice-contracts-v4/src/interfaces/IJBDirectory.sol";
import {IJBProjects} from "lib/juice-contracts-v4/src/interfaces/IJBProjects.sol";
import {IJBPermissions} from "lib/juice-contracts-v4/src/interfaces/IJBPermissions.sol";

import {JB721Tier} from "./structs/JB721Tier.sol";
import {JB721TiersHook} from "./JB721TiersHook.sol";

/// @title JBGoverned721TiersHook
/// @notice A 721 tiers hook where each NFT can be used for onchain governance.
contract JBGoverned721TiersHook is Votes, JB721TiersHook {
    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param directory A directory of terminals and controllers for projects.
    /// @param permissions The operatorStore that will be used to check operator permissions.
    constructor(
        IJBDirectory directory,
        IJBPermissions permissions
    )
        EIP712("Juicebox 721 Governance Hook", "1")
        JB721TiersHook(directory, permissions)
    {}

    //*********************************************************************//
    // ------------------------ internal functions ----------------------- //
    //*********************************************************************//

    /// @notice The total number of votes that the specified address has from its NFTs (across all tiers).
    /// @dev If an NFT's tier specifies a number of voting units, then that number of voting units is used. Otherwise,
    /// the NFT's price is used.
    /// @param account The address to get the voting units of.
    /// @return units The number of voting units that the address has.
    function _getVotingUnits(address account) internal view virtual override returns (uint256 units) {
        return STORE.votingUnitsOf(address(this), account);
    }

    /// @notice After an NFT is transferred, update the voting units of the sender and receiver accordingly.
    /// @param from The address that the NFT was transferred from.
    /// @param to The address that the NFT was transferred to.
    /// @param tokenId The token ID of the NFT that was transferred.
    /// @param tier The tier of the NFT that was transferred.
    function _afterTokenTransferAccounting(
        address from,
        address to,
        uint256 tokenId,
        JB721Tier memory tier
    )
        internal
        virtual
        override
    {
        tokenId; // Prevents unused var compiler and natspec complaints.

        if (tier.votingUnits != 0) {
            // Transfer the voting units.
            _transferVotingUnits(from, to, tier.votingUnits);
        }
    }
}
