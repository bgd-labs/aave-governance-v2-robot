// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {EthRobotKeeper} from '../src/contracts/EthRobotKeeper.sol';
import {IAaveGovernanceV2, AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import 'forge-std/console.sol';

contract EthRobotKeeperTest is Test {
  EthRobotKeeper public ethRobotKeeper;
  function setUp() public {
    ethRobotKeeper = new EthRobotKeeper();
  }

  function testSimpleQueue() public {
    vm.createSelectFork(
      'https://eth-mainnet.g.alchemy.com/v2/KsQvoVtnvpWhdPOlcK2Ks8u6COVwW_Uz', 
      16613098 // Feb-12-2023
    );
    IAaveGovernanceV2.ProposalState initialProposalState = AaveGovernanceV2.GOV.getProposalState(153);
    assertEq(uint256(initialProposalState), 4);
    console.log('Initial State of Proposal 153', uint256(initialProposalState));
    
    (bool shouldRunKeeper, bytes memory performData) = ethRobotKeeper.checkUpkeep(abi.encode(address(AaveGovernanceV2.GOV)));

    if (shouldRunKeeper) {
      ethRobotKeeper.performUpkeep(performData);
      IAaveGovernanceV2.ProposalState finalProposalState = AaveGovernanceV2.GOV.getProposalState(153);
      assertEq(uint256(finalProposalState), 5);
      console.log('Final State of Proposal 153 after automation', uint256(finalProposalState));
    }
  }

  function testSimpleExecute() public {
    vm.createSelectFork(
      'https://eth-mainnet.g.alchemy.com/v2/KsQvoVtnvpWhdPOlcK2Ks8u6COVwW_Uz', 
      16620260 // Feb-13-2023
    );
    IAaveGovernanceV2.ProposalState initialProposalState = AaveGovernanceV2.GOV.getProposalState(153);
    assertEq(uint256(initialProposalState), 5);
    console.log('Initial State of Proposal 153', uint256(initialProposalState));

    (bool shouldRunKeeper, bytes memory performData) = ethRobotKeeper.checkUpkeep(abi.encode(address(AaveGovernanceV2.GOV)));

    if (shouldRunKeeper) {
      ethRobotKeeper.performUpkeep(performData);
      IAaveGovernanceV2.ProposalState finalProposalState = AaveGovernanceV2.GOV.getProposalState(153);
      assertEq(uint256(finalProposalState), 7);
      console.log('Final State of Proposal 153 after automation', uint256(finalProposalState));
    }
  }
}
