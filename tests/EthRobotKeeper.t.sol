// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {EthRobotKeeper} from '../src/contracts/EthRobotKeeper.sol';
import {IAaveGovernanceV2, AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import 'forge-std/console.sol';

contract EthRobotKeeperTest is Test {

  function testSimpleQueue() public {
    vm.createSelectFork(
      'https://eth-mainnet.g.alchemy.com/v2/KsQvoVtnvpWhdPOlcK2Ks8u6COVwW_Uz', 
      16613098 // Feb-12-2023
    );
    EthRobotKeeper ethRobotKeeper = new EthRobotKeeper();

    IAaveGovernanceV2.ProposalState proposalState = AaveGovernanceV2.GOV.getProposalState(153);
    assertEq(uint256(proposalState), 4);
    console.log('Initial State of Proposal 153: Succeeded', uint256(proposalState));
    
    (bool shouldRunKeeper, bytes memory performData) = ethRobotKeeper.checkUpkeep(abi.encode(address(AaveGovernanceV2.GOV)));

    if (shouldRunKeeper) {
      ethRobotKeeper.performUpkeep(performData);
      proposalState = AaveGovernanceV2.GOV.getProposalState(153);
      assertEq(uint256(proposalState), 5);
      console.log('Final State of Proposal 153 after automation: Queued', uint256(proposalState));
    }
  }

  function testSimpleExecute() public {
    vm.createSelectFork(
      'https://eth-mainnet.g.alchemy.com/v2/KsQvoVtnvpWhdPOlcK2Ks8u6COVwW_Uz', 
      16620260 // Feb-13-2023
    );
    EthRobotKeeper ethRobotKeeper = new EthRobotKeeper();

    IAaveGovernanceV2.ProposalState proposalState = AaveGovernanceV2.GOV.getProposalState(153);
    assertEq(uint256(proposalState), 5);
    console.log('Initial State of Proposal 153: Queued', uint256(proposalState));

    (bool shouldRunKeeper, bytes memory performData) = ethRobotKeeper.checkUpkeep(abi.encode(address(AaveGovernanceV2.GOV)));

    if (shouldRunKeeper) {
      ethRobotKeeper.performUpkeep(performData);
      proposalState = AaveGovernanceV2.GOV.getProposalState(153);
      assertEq(uint256(proposalState), 7);
      console.log('Final State of Proposal 153 after automation: Executed', uint256(proposalState));
    }
  }

  function testSimpleCancel() public {
    vm.createSelectFork(
      'https://eth-mainnet.g.alchemy.com/v2/KsQvoVtnvpWhdPOlcK2Ks8u6COVwW_Uz', 
      12172974 // Apr-04-2021
    );
    EthRobotKeeper ethRobotKeeper = new EthRobotKeeper();

    IAaveGovernanceV2.ProposalState proposalState = AaveGovernanceV2.GOV.getProposalState(6);
    assertEq(uint256(proposalState), 2);
    console.log('Initial State of Proposal 6: Active', uint256(proposalState));
    (bool shouldRunKeeper, bytes memory performData) = ethRobotKeeper.checkUpkeep(abi.encode(address(AaveGovernanceV2.GOV)));

    if (shouldRunKeeper) {
      ethRobotKeeper.performUpkeep(performData);
      proposalState = AaveGovernanceV2.GOV.getProposalState(6);
      assertEq(uint256(proposalState), 1);
      console.log('Final State of Proposal 6 after automation: Cancelled', uint256(proposalState));
    }
  }
}
