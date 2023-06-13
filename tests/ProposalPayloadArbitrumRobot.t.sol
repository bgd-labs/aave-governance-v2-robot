// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Deploy} from '../scripts/DeployArbitrumPayload.s.sol';
import {ProposalPayloadArbitrumRobot} from '../src/proposal/ProposalPayloadArbitrumRobot.sol';
import {TestWithExecutor} from 'aave-helpers/GovHelpers.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';

contract ProposalPayloadArbitrumRobotTest is TestWithExecutor {
  ProposalPayloadArbitrumRobot public payload;

  event ChainlinkUpkeepRegistered(string indexed name, uint256 indexed upkeedId);

  function setUp() public {
    vm.createSelectFork('arbitrum', 91945000);
    _selectPayloadExecutor(AaveGovernanceV2.ARBITRUM_BRIDGE_EXECUTOR);
  }

  function testExecuteProposalArbitrum() public {
    // deploy all contracts
    Deploy script = new Deploy();
    script.run();

    payload = script.payload();
    vm.expectEmit(true, false, false, false);
    emit ChainlinkUpkeepRegistered('AaveArbRobotKeeperV2', 0);

    // Execute proposal
    _executor.execute(address(payload));
  }
}
