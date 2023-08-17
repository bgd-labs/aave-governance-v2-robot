// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Deploy} from '../scripts/DeployOptimismPayload.s.sol';
import {ProposalPayloadOptimismRobot} from '../src/proposal/ProposalPayloadOptimismRobot.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {GovHelpers} from 'aave-helpers/GovHelpers.sol';
import {Test} from 'forge-std/Test.sol';

contract ProposalPayloadOptimismRobotTest is Test {
  ProposalPayloadOptimismRobot public payload;
  event KeeperRefilled(uint256 indexed id, address indexed from, uint96 indexed amount);

  function setUp() public {
    vm.createSelectFork('optimism', 108328314);
  }

  function testExecuteProposalOptimism() public {
    Deploy script = new Deploy();
    script.run();

    payload = script.payload();
    vm.expectEmit(true, true, true, false);
    emit KeeperRefilled(script.KEEPER_ID(), AaveGovernanceV2.OPTIMISM_BRIDGE_EXECUTOR, uint96(script.AMOUNT_TO_FUND()));

    // Execute proposal
    GovHelpers.executePayload(vm, address(payload), AaveGovernanceV2.OPTIMISM_BRIDGE_EXECUTOR);
  }
}
