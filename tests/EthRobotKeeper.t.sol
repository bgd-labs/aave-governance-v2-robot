// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {EthRobotKeeper} from '../src/contracts/EthRobotKeeper.sol';
import {IAaveGovernanceV2, AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {GovernanceHelpers} from './helpers/GovernanceHelpers.sol';
import 'forge-std/console.sol';

contract EthRobotKeeperTest is Test {
  function testSimpleQueue() public {
    vm.createSelectFork(
      'mainnet',
      16613098 // Feb-12-2023
    );
    EthRobotKeeper ethRobotKeeper = new EthRobotKeeper(AaveGovernanceV2.GOV);
    IAaveGovernanceV2.ProposalState proposalState = AaveGovernanceV2.GOV.getProposalState(153);
    assertEq(uint256(proposalState), 4);
    console.log('Initial State of Proposal 153: Succeeded', uint256(proposalState));

    checkAndPerformUpKeep(ethRobotKeeper);

    proposalState = AaveGovernanceV2.GOV.getProposalState(153);
    assertEq(uint256(proposalState), 5);
    console.log('Final State of Proposal 153 after automation: Queued', uint256(proposalState));
  }

  function testSimpleExecute() public {
    vm.createSelectFork(
      'mainnet',
      16620260 // Feb-13-2023
    );
    EthRobotKeeper ethRobotKeeper = new EthRobotKeeper(AaveGovernanceV2.GOV);
    IAaveGovernanceV2.ProposalState proposalState = AaveGovernanceV2.GOV.getProposalState(153);
    assertEq(uint256(proposalState), 5);
    console.log('Initial State of Proposal 153: Queued', uint256(proposalState));

    checkAndPerformUpKeep(ethRobotKeeper);

    proposalState = AaveGovernanceV2.GOV.getProposalState(153);
    assertEq(uint256(proposalState), 7);
    console.log('Final State of Proposal 153 after automation: Executed', uint256(proposalState));
  }

  function testSimpleCancel() public {
    vm.createSelectFork(
      'mainnet',
      12172974 // Apr-04-2021
    );
    EthRobotKeeper ethRobotKeeper = new EthRobotKeeper(AaveGovernanceV2.GOV);
    IAaveGovernanceV2.ProposalState proposalState = AaveGovernanceV2.GOV.getProposalState(6);
    assertEq(uint256(proposalState), 2);
    console.log('Initial State of Proposal 6: Active', uint256(proposalState));

    checkAndPerformUpKeep(ethRobotKeeper);

    proposalState = AaveGovernanceV2.GOV.getProposalState(6);
    assertEq(uint256(proposalState), 1);
    console.log('Final State of Proposal 6 after automation: Cancelled', uint256(proposalState));
  }

  // initial states -> (proposalId: 6: Active) ...(proposalId: 7 to 11: Executed)... (proposalId 12: Succeeded)
  // final states -> (proposalId: 6: Cancelled) ...(proposalId: 7 to 11: Executed)... (proposalId 12: Queued)
  function testMutilpleActions() public {
    vm.createSelectFork(
      'mainnet',
      12172974 // Apr-04-2021
    );
    GovernanceHelpers governanceHelpers = new GovernanceHelpers();
    EthRobotKeeper ethRobotKeeper = new EthRobotKeeper(AaveGovernanceV2.GOV);

    IAaveGovernanceV2.ProposalState proposal6State = AaveGovernanceV2.GOV.getProposalState(6);
    assertEq(uint256(proposal6State), 2);
    console.log('Initial State of Proposal 6: Active', uint256(proposal6State));

    for (uint i = 0; i < 5; i++) {
      governanceHelpers.createDummyProposal(vm, IAaveGovernanceV2.ProposalState.Executed);
    }
    governanceHelpers.createDummyProposal(vm, IAaveGovernanceV2.ProposalState.Succeeded);

    IAaveGovernanceV2.ProposalState proposal12State = AaveGovernanceV2.GOV.getProposalState(12);
    assertEq(uint256(proposal12State), 4);
    console.log('Initial State of Proposal 12: Succeeded', uint256(proposal12State));

    checkAndPerformUpKeep(ethRobotKeeper);

    proposal6State = AaveGovernanceV2.GOV.getProposalState(6);
    assertEq(uint256(proposal6State), 1);
    console.log('Final State of Proposal 6: Cancelled', uint256(proposal6State));

    proposal12State = AaveGovernanceV2.GOV.getProposalState(12);
    assertEq(uint256(proposal12State), 5);
    console.log('Final State of Proposal 12: Queued', uint256(proposal12State));
  }

  // initial states -> (proposalId: 6: Active) ...(proposalId: 7 to 11: Executed)... (proposalId 12: Succeeded)
  // final states -> (proposalId: 6: Succeeded) ...(proposalId: 7 to 11: Executed)... (proposalId 12: Queued)
  function testMutilpleActionsWithOneDisabled() public {
    vm.createSelectFork(
      'mainnet',
      12172974 // Apr-04-2021
    );

    GovernanceHelpers governanceHelpers = new GovernanceHelpers();
    EthRobotKeeper ethRobotKeeper = new EthRobotKeeper(AaveGovernanceV2.GOV);
    ethRobotKeeper.disableAutomation(6);

    vm.startPrank(address(2));
    vm.expectRevert('Ownable: caller is not the owner');
    ethRobotKeeper.disableAutomation(6);
    vm.stopPrank();

    IAaveGovernanceV2.ProposalState proposal6State = AaveGovernanceV2.GOV.getProposalState(6);
    assertEq(uint256(proposal6State), 2);
    console.log('Initial State of Proposal 6: Active', uint256(proposal6State));

    for (uint i = 0; i < 5; i++) {
      governanceHelpers.createDummyProposal(vm, IAaveGovernanceV2.ProposalState.Executed);
    }
    governanceHelpers.createDummyProposal(vm, IAaveGovernanceV2.ProposalState.Succeeded);
    IAaveGovernanceV2.ProposalState proposal12State = AaveGovernanceV2.GOV.getProposalState(12);
    assertEq(uint256(proposal12State), 4);
    console.log('Initial State of Proposal 12: Succeeded', uint256(proposal12State));

    checkAndPerformUpKeep(ethRobotKeeper);

    proposal6State = AaveGovernanceV2.GOV.getProposalState(6);
    assertTrue(uint256(proposal6State) != 1);
    console.log('Final State of Proposal 6: Succeeded (Not Cancelled)', uint256(proposal6State));

    proposal12State = AaveGovernanceV2.GOV.getProposalState(12);
    assertEq(uint256(proposal12State), 5);
    console.log('Final State of Proposal 12: Queued', uint256(proposal12State));
  }

  function checkAndPerformUpKeep(EthRobotKeeper ethRobotKeeper) private {
    (bool shouldRunKeeper, bytes memory performData) = ethRobotKeeper.checkUpkeep('');
    if (shouldRunKeeper) {
      ethRobotKeeper.performUpkeep(performData);
    }
  }
}
