// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Deploy} from '../scripts/DeployPolygonPayload.s.sol';
import {ProposalPayloadPolygonRobot} from '../src/proposal/ProposalPayloadPolygonRobot.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {GovHelpers} from 'aave-helpers/GovHelpers.sol';
import {Test} from 'forge-std/Test.sol';

contract ProposalPayloadPolygonRobotTest is Test {
  ProposalPayloadPolygonRobot public payload;
  event KeeperRefilled(uint256 indexed id, address indexed from, uint96 indexed amount);

  function setUp() public {
    vm.createSelectFork('polygon', 46406796);
  }

  function testExecuteProposalPolygon() public {
    Deploy script = new Deploy();
    script.run();

    payload = script.proposal();
    vm.expectEmit(true, true, true, false);
    emit KeeperRefilled(script.KEEPER_ID(), AaveGovernanceV2.POLYGON_BRIDGE_EXECUTOR, uint96(script.AMOUNT_TO_FUND()));

    // Execute proposal
    GovHelpers.executePayload(vm, address(payload), AaveGovernanceV2.POLYGON_BRIDGE_EXECUTOR);
  }
}
