pragma solidity 0.8.23;

import "./Pay_Mint_Redeem_E2E.t.sol";

import "src/JBGoverned721TiersHook.sol";
import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract TestJB721TiersHookGovernance is TestJBTieredNFTRewardDelegateE2E {
    using JBRulesetMetadataResolver for JBRuleset;

    function testMintAndTransferGlobalVotingUnits(uint256 _tier, bool _recipientDelegated) public {
        address _user = address(bytes20(keccak256("user")));
        address _userFren = address(bytes20(keccak256("user_fren")));
        (JBDeploy721TiersHookConfig memory tiered721DeployerData, JBLaunchProjectConfig memory launchProjectConfig) =
            createData();
        // _tier has to be a valid tier (0-indexed)
        _tier = bound(_tier, 0, tiered721DeployerData.tiersConfig.tiers.length - 1);
        // Set the governance type to tiered
        tiered721DeployerData.governanceType = JB721GovernanceType.ONCHAIN;
        JBGoverned721TiersHook _hook;
        // to handle stack too deep
        {
            uint256 projectId =
                deployer.launchProjectFor(projectOwner, tiered721DeployerData, launchProjectConfig, jbController);
            // Get the dataSource
            _hook = JBGoverned721TiersHook(jbRulesets.currentOf(projectId).dataHook());
            uint256 _payAmount = tiered721DeployerData.tiersConfig.tiers[_tier].price;
            assertEq(_hook.delegates(_user), address(0));
            vm.prank(_user);
            _hook.delegate(_user);
            // Pay and mint an NFT
            vm.deal(_user, _payAmount);
            vm.prank(_user);
            bytes memory _delegateMetadata;
            {
                // Craft the metadata: mint the specified tier
                uint16[] memory rawMetadata = new uint16[](1);
                rawMetadata[0] = uint16(_tier + 1); // 1 indexed

                bytes[] memory _data = new bytes[](1);
                _data[0] = abi.encode(true, rawMetadata);

                // Pass the hook id
                bytes4[] memory _ids = new bytes4[](1);
                _ids[0] = bytes4(bytes20(address(_hook)));

                // Generate the metadata
                _delegateMetadata = metadataHelper.createMetadata(_ids, _data);
            }
            jbMultiTerminal.pay{value: _payAmount}({
                projectId: projectId,
                amount: 100,
                token: JBConstants.NATIVE_TOKEN,
                beneficiary: _user,
                minReturnedTokens: 0,
                memo: "Take my money!",
                metadata: _delegateMetadata
            });
        }
        // Assert that the user received the votingUnits
        assertEq(_hook.getVotes(_user), tiered721DeployerData.tiersConfig.tiers[_tier].votingUnits);
        uint256 _frenExpectedVotes = 0;
        // Have the user delegate to themselves
        if (_recipientDelegated) {
            _frenExpectedVotes = tiered721DeployerData.tiersConfig.tiers[_tier].votingUnits;
            vm.prank(_userFren);
            _hook.delegate(_userFren);
        }
        // Transfer NFT to fren
        vm.prank(_user);
        ERC721(address(_hook)).transferFrom(_user, _userFren, _generateTokenId(_tier + 1, 1));
        // Assert that the user lost their voting units
        assertEq(_hook.getVotes(_user), 0);
        // Assert that fren received the voting units
        assertEq(_hook.getVotes(_userFren), _frenExpectedVotes);
    }

    function testMintAndDelegateVotingUnits(uint256 _tier, bool _selfDelegateBeforeReceive) public {
        address _user = address(bytes20(keccak256("user")));
        address _userFren = address(bytes20(keccak256("user_fren")));

        JBDeploy721TiersHookConfig memory tiered721DeployerData;
        uint256 projectId;
        JBGoverned721TiersHook _hook;

        {
            JBLaunchProjectConfig memory launchProjectConfig;
            (tiered721DeployerData, launchProjectConfig) = createData();
            // _tier has to be a valid tier (0-indexed)
            _tier = bound(_tier, 0, tiered721DeployerData.tiersConfig.tiers.length - 1);
            // Set the governance type to tiered
            tiered721DeployerData.governanceType = JB721GovernanceType.ONCHAIN;
            projectId =
                deployer.launchProjectFor(projectOwner, tiered721DeployerData, launchProjectConfig, jbController);
            // Get the dataSource
            _hook = JBGoverned721TiersHook(jbRulesets.currentOf(projectId).dataHook());
            // Delegate NFT to fren
            vm.startPrank(_user);
            _hook.delegate(_userFren);
            // Delegate NFT to self
            if (_selfDelegateBeforeReceive) {
                _hook.delegate(_user);
            }
        }

        {
            uint256 _payAmount = tiered721DeployerData.tiersConfig.tiers[_tier].price;

            // Craft the metadata: mint the specified tier
            uint16[] memory rawMetadata = new uint16[](1);
            rawMetadata[0] = uint16(_tier + 1); // 1 indexed

            // Build the metadata with the tiers to mint and the overspending flag
            bytes[] memory _data = new bytes[](1);
            _data[0] = abi.encode(true, rawMetadata);

            // Pass the hook id
            bytes4[] memory _ids = new bytes4[](1);
            _ids[0] = bytes4(bytes20(address(_hook)));

            // Generate the metadata
            bytes memory _delegateMetadata = metadataHelper.createMetadata(_ids, _data);

            // Pay and mint an NFT
            vm.deal(_user, _payAmount);
            jbMultiTerminal.pay{value: _payAmount}({
                projectId: projectId,
                amount: 100,
                token: JBConstants.NATIVE_TOKEN,
                beneficiary: _user,
                minReturnedTokens: 0,
                memo: "Take my money!",
                metadata: _delegateMetadata
            });
        }
        // Delegate NFT to self
        if (!_selfDelegateBeforeReceive) {
            _hook.delegate(_user);
        }
        // Assert that the user received the votingUnits
        assertEq(_hook.getVotes(_user), tiered721DeployerData.tiersConfig.tiers[_tier].votingUnits);
        // Delegate to the users fren
        _hook.delegate(_userFren);
        vm.stopPrank();
        // Assert that the user lost their voting units
        assertEq(_hook.getVotes(_user), 0);
        // Assert that fren received the voting units
        assertEq(_hook.getVotes(_userFren), tiered721DeployerData.tiersConfig.tiers[_tier].votingUnits);
    }
}
