// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {EthRobotKeeper} from '../src/contracts/EthRobotKeeper.sol';
import {IAaveGovernanceV2, AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {GovernanceHelpers} from './helpers/GovernanceHelpers.sol';

contract EthRobotKeeperTest is Test {
  function testQueue() public {
    vm.createSelectFork(
      'mainnet',
      16613098 // Feb-12-2023
    );

    EthRobotKeeper ethRobotKeeper = new EthRobotKeeper(address(AaveGovernanceV2.GOV));
    IAaveGovernanceV2.ProposalState proposalState = AaveGovernanceV2.GOV.getProposalState(153);
    assertEq(uint256(proposalState), uint256(IAaveGovernanceV2.ProposalState.Succeeded));

    checkAndPerformUpKeep(ethRobotKeeper);

    proposalState = AaveGovernanceV2.GOV.getProposalState(153);
    assertEq(uint256(proposalState), uint256(IAaveGovernanceV2.ProposalState.Queued));
  }

  function testExecute() public {
    vm.createSelectFork(
      'mainnet',
      16620260 // Feb-13-2023
    );
    EthRobotKeeper ethRobotKeeper = new EthRobotKeeper(address(AaveGovernanceV2.GOV));

    IAaveGovernanceV2.ProposalState proposalState = AaveGovernanceV2.GOV.getProposalState(153);
    assertEq(uint256(proposalState), uint256(IAaveGovernanceV2.ProposalState.Queued));

    checkAndPerformUpKeep(ethRobotKeeper);

    proposalState = AaveGovernanceV2.GOV.getProposalState(153);
    assertEq(uint256(proposalState), uint256(IAaveGovernanceV2.ProposalState.Executed));
  }

  function testCancel() public {
    vm.createSelectFork(
      'mainnet',
      12172974 // Apr-04-2021
    );

    EthRobotKeeper ethRobotKeeper = new EthRobotKeeper(address(AaveGovernanceV2.GOV));

    IAaveGovernanceV2.ProposalState proposalState = AaveGovernanceV2.GOV.getProposalState(6);
    assertEq(uint256(proposalState), uint256(IAaveGovernanceV2.ProposalState.Active));

    checkAndPerformUpKeep(ethRobotKeeper);

    proposalState = AaveGovernanceV2.GOV.getProposalState(6);
    assertEq(uint256(proposalState), uint256(IAaveGovernanceV2.ProposalState.Canceled));
  }

  // initial states -> (proposalId: 6: Active) ...(proposalId: 7 to 11: Executed)... (proposalId 12: Succeeded)
  // final states -> (proposalId: 6: Cancelled) ...(proposalId: 7 to 11: Executed)... (proposalId 12: Queued)
  function testMutilpleActions() public {
    vm.createSelectFork(
      'mainnet',
      12172974 // Apr-04-2021
    );
    GovernanceHelpers governanceHelpers = new GovernanceHelpers();
    EthRobotKeeper ethRobotKeeper = new EthRobotKeeper(address(AaveGovernanceV2.GOV));

    IAaveGovernanceV2.ProposalState proposal6State = AaveGovernanceV2.GOV.getProposalState(6);
    assertEq(uint256(proposal6State), uint256(IAaveGovernanceV2.ProposalState.Active));

    for (uint i = 0; i < 5; i++) {
      governanceHelpers.createDummyProposal(vm, IAaveGovernanceV2.ProposalState.Executed);
    }
    governanceHelpers.createDummyProposal(vm, IAaveGovernanceV2.ProposalState.Succeeded);

    IAaveGovernanceV2.ProposalState proposal12State = AaveGovernanceV2.GOV.getProposalState(12);
    assertEq(uint256(proposal12State), uint256(IAaveGovernanceV2.ProposalState.Succeeded));

    checkAndPerformUpKeep(ethRobotKeeper);

    proposal6State = AaveGovernanceV2.GOV.getProposalState(6);
    assertEq(uint256(proposal6State), uint256(IAaveGovernanceV2.ProposalState.Canceled));

    proposal12State = AaveGovernanceV2.GOV.getProposalState(12);
    assertEq(uint256(proposal12State), uint256(IAaveGovernanceV2.ProposalState.Queued));
  }

  // initial states -> (proposalId: 153: Queued) (proposalId: 154: Queued) (proposalId 156: Queued)
  // final states -> (proposalId: 153: Executed) (proposalId: 154: Executed) (proposalId 156: Executed)
  function testMultipleExecute() public {
    vm.createSelectFork(
      'mainnet',
      16620260 // Feb-13-2023
    );

    GovernanceHelpers governanceHelpers = new GovernanceHelpers();
    EthRobotKeeper ethRobotKeeper = new EthRobotKeeper(address(AaveGovernanceV2.GOV));

    governanceHelpers.createDummyProposal(vm, IAaveGovernanceV2.ProposalState.Queued);
    vm.warp(block.timestamp + 1);
    uint256 proposalId = governanceHelpers.createDummyProposal(
      vm,
      IAaveGovernanceV2.ProposalState.Queued
    );
    vm.warp(AaveGovernanceV2.GOV.getProposalById(proposalId).executionTime + 1);

    assertEq(
      uint256(AaveGovernanceV2.GOV.getProposalState(153)),
      uint256(IAaveGovernanceV2.ProposalState.Queued)
    );
    assertEq(
      uint256(AaveGovernanceV2.GOV.getProposalState(154)),
      uint256(IAaveGovernanceV2.ProposalState.Queued)
    );
    assertEq(
      uint256(AaveGovernanceV2.GOV.getProposalState(155)),
      uint256(IAaveGovernanceV2.ProposalState.Queued)
    );

    checkAndPerformUpKeep(ethRobotKeeper);
    checkAndPerformUpKeep(ethRobotKeeper);
    checkAndPerformUpKeep(ethRobotKeeper);

    assertEq(
      uint256(AaveGovernanceV2.GOV.getProposalState(153)),
      uint256(IAaveGovernanceV2.ProposalState.Executed)
    );
    assertEq(
      uint256(AaveGovernanceV2.GOV.getProposalState(154)),
      uint256(IAaveGovernanceV2.ProposalState.Executed)
    );
    assertEq(
      uint256(AaveGovernanceV2.GOV.getProposalState(155)),
      uint256(IAaveGovernanceV2.ProposalState.Executed)
    );
  }

  // initial states -> (proposalId: 153: Queued) (proposalId: 154: Queued) (proposalId 156: Queued)
  // final states -> (proposalId: 153: Queued) (proposalId: 154: Executed) (proposalId 156: Queued)
  function testOnlyOneExecuteAtATime() public {
    vm.createSelectFork(
      'mainnet',
      16620260 // Feb-13-2023
    );

    GovernanceHelpers governanceHelpers = new GovernanceHelpers();
    EthRobotKeeper ethRobotKeeper = new EthRobotKeeper(address(AaveGovernanceV2.GOV));

    governanceHelpers.createDummyProposal(vm, IAaveGovernanceV2.ProposalState.Queued);
    vm.warp(block.timestamp + 1);
    uint256 proposalId = governanceHelpers.createDummyProposal(
      vm,
      IAaveGovernanceV2.ProposalState.Queued
    );
    vm.warp(AaveGovernanceV2.GOV.getProposalById(proposalId).executionTime + 4);

    assertEq(
      uint256(AaveGovernanceV2.GOV.getProposalState(153)),
      uint256(IAaveGovernanceV2.ProposalState.Queued)
    );
    assertEq(
      uint256(AaveGovernanceV2.GOV.getProposalState(154)),
      uint256(IAaveGovernanceV2.ProposalState.Queued)
    );
    assertEq(
      uint256(AaveGovernanceV2.GOV.getProposalState(155)),
      uint256(IAaveGovernanceV2.ProposalState.Queued)
    );

    checkAndPerformUpKeep(ethRobotKeeper);

    // random execution depends on the blocknumber and timestamp so we know before that only proposalId 154 is getting executed
    assertEq(
      uint256(AaveGovernanceV2.GOV.getProposalState(153)),
      uint256(IAaveGovernanceV2.ProposalState.Queued)
    );
    assertEq(
      uint256(AaveGovernanceV2.GOV.getProposalState(154)),
      uint256(IAaveGovernanceV2.ProposalState.Executed)
    );
    assertEq(
      uint256(AaveGovernanceV2.GOV.getProposalState(155)),
      uint256(IAaveGovernanceV2.ProposalState.Queued)
    );
  }

  // initial states -> (proposalId: 6: Active) (proposalId 7: Queued)
  // final states -> (proposalId: 6: Cancelled) (proposalId 7: Queued) -> (proposalId: 6: Cancelled) (proposalId 7: Executed)
  function testOtherActionsBeforeExecute(uint256 n) public {
    vm.createSelectFork(
      'mainnet',
      12172974 // Apr-04-2021
    );
    GovernanceHelpers governanceHelpers = new GovernanceHelpers();
    EthRobotKeeper ethRobotKeeper = new EthRobotKeeper(address(AaveGovernanceV2.GOV));

    IAaveGovernanceV2.ProposalState proposal6State = AaveGovernanceV2.GOV.getProposalState(6);

    uint256 proposalId = governanceHelpers.createDummyProposal(
      vm,
      IAaveGovernanceV2.ProposalState.Queued
    );

    vm.assume(n!=0 && n < 432000);
    // we change the timestamp to be after timelock elapses and before grace period expiration
    // changing the timestamp will randomize the order of execution of actions.
    vm.warp(AaveGovernanceV2.GOV.getProposalById(proposalId).executionTime + n);

    IAaveGovernanceV2.ProposalState proposal7State = AaveGovernanceV2.GOV.getProposalState(7);

    assertEq(uint256(proposal6State), uint256(IAaveGovernanceV2.ProposalState.Active));
    assertEq(uint256(proposal7State), uint256(IAaveGovernanceV2.ProposalState.Queued));

    checkAndPerformUpKeep(ethRobotKeeper);

    proposal6State = AaveGovernanceV2.GOV.getProposalState(6);
    proposal7State = AaveGovernanceV2.GOV.getProposalState(7);
    assertEq(uint256(proposal6State), uint256(IAaveGovernanceV2.ProposalState.Canceled));
    assertEq(uint256(proposal7State), uint256(IAaveGovernanceV2.ProposalState.Queued));

    checkAndPerformUpKeep(ethRobotKeeper);

    proposal7State = AaveGovernanceV2.GOV.getProposalState(7);
    assertEq(uint256(proposal7State), uint256(IAaveGovernanceV2.ProposalState.Executed));
  }

  // initial states -> (proposalId: 6: Active) ...(proposalId: 7 to 11: Executed)... (proposalId 12: Succeeded)
  // final states -> (proposalId: 6: Succeeded) ...(proposalId: 7 to 11: Executed)... (proposalId 12: Queued)
  function testMutilpleActionsWithOneDisabled() public {
    vm.createSelectFork(
      'mainnet',
      12172974 // Apr-04-2021
    );

    GovernanceHelpers governanceHelpers = new GovernanceHelpers();

    EthRobotKeeper ethRobotKeeper = new EthRobotKeeper(address(AaveGovernanceV2.GOV));

    vm.startPrank(ethRobotKeeper.owner());
    ethRobotKeeper.toggleDisableAutomationById(6);
    vm.stopPrank();

    IAaveGovernanceV2.ProposalState proposal6State = AaveGovernanceV2.GOV.getProposalState(6);
    assertEq(uint256(proposal6State), uint256(IAaveGovernanceV2.ProposalState.Active));

    for (uint i = 0; i < 5; i++) {
      governanceHelpers.createDummyProposal(vm, IAaveGovernanceV2.ProposalState.Executed);
    }
    governanceHelpers.createDummyProposal(vm, IAaveGovernanceV2.ProposalState.Succeeded);
    IAaveGovernanceV2.ProposalState proposal12State = AaveGovernanceV2.GOV.getProposalState(12);
    assertEq(uint256(proposal12State), uint256(IAaveGovernanceV2.ProposalState.Succeeded));

    checkAndPerformUpKeep(ethRobotKeeper);

    proposal6State = AaveGovernanceV2.GOV.getProposalState(6);
    assertTrue(uint256(proposal6State) != uint256(IAaveGovernanceV2.ProposalState.Canceled));

    proposal12State = AaveGovernanceV2.GOV.getProposalState(12);
    assertEq(uint256(proposal12State), uint256(IAaveGovernanceV2.ProposalState.Queued));
  }

  function checkAndPerformUpKeep(EthRobotKeeper ethRobotKeeper) private {
    (bool shouldRunKeeper, bytes memory performData) = ethRobotKeeper.checkUpkeep('');
    if (shouldRunKeeper) {
      ethRobotKeeper.performUpkeep(performData);
    }
  }
}
