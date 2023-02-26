// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Deploy} from '../scripts/DeployPolygonRobotKeeper.s.sol';
import {ProposalPayloadPolygonRobot} from '../src/proposal/ProposalPayloadPolygonRobot.sol';
import {TestWithExecutor} from 'aave-helpers/GovHelpers.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';

contract ProposalPayloadPolygonRobotTest is TestWithExecutor {
  ProposalPayloadPolygonRobot public payload;

  event ChainlinkUpkeepRegistered(string indexed name, uint256 indexed upkeedId);

  function setUp() public {
    vm.createSelectFork(
      'polygon',
      39706700 // Feb-09-2023
    );
    _selectPayloadExecutor(AaveGovernanceV2.POLYGON_BRIDGE_EXECUTOR);
  }

  function testExecuteProposal() public {
    // deploy all contracts
    Deploy script = new Deploy();
    script.run();

    payload = script.proposal();
    vm.expectEmit(true, false, false, false);
    emit ChainlinkUpkeepRegistered('AavePolygonRobotKeeperV2', 0);

    // Execute proposal
    _executor.execute(address(payload));
  }
}
