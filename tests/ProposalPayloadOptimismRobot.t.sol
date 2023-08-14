// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Deploy} from '../scripts/DeployOptimismPayload.s.sol';
import {ProposalPayloadOptimismRobot} from '../src/proposal/ProposalPayloadOptimismRobot.sol';
import {TestWithExecutor} from 'aave-helpers/GovHelpers.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';

contract ProposalPayloadOptimismRobotTest is TestWithExecutor {
  ProposalPayloadOptimismRobot public payload;

  event ChainlinkUpkeepRegistered(string indexed name, uint256 indexed upkeedId);

  function setUp() public {
    vm.createSelectFork('optimism', 99549575);
    _selectPayloadExecutor(AaveGovernanceV2.OPTIMISM_BRIDGE_EXECUTOR);
  }

  function testExecuteProposalOptimism() public {
    // deploy all contracts
    Deploy script = new Deploy();
    script.run();

    payload = script.payload();
    vm.expectEmit(true, false, false, false);
    emit ChainlinkUpkeepRegistered('AaveOptRobotKeeperV2', 0);

    // Execute proposal
    _executor.execute(address(payload));
  }
}
