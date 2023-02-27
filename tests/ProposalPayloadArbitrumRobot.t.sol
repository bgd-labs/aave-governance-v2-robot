// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Deploy} from '../scripts/DeployArbitrumRobotKeeper.s.sol';
import {ProposalPayloadArbitrumRobot} from '../src/proposal/ProposalPayloadArbitrumRobot.sol';
import {TestWithExecutor} from 'aave-helpers/GovHelpers.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';

contract ProposalPayloadArbitrumRobotTest is TestWithExecutor {
  ProposalPayloadArbitrumRobot public payload;

  event ChainlinkUpkeepRegistered(string indexed name, uint256 indexed upkeedId);

  function setUp() public {
    vm.createSelectFork(
      'arbitrum',
      64999658 // Feb-27-2023
    );
    _selectPayloadExecutor(AaveGovernanceV2.ARBITRUM_BRIDGE_EXECUTOR);
  }

  function testExecuteProposalArbitrum() public {
    // deploy all contracts
    Deploy script = new Deploy();
    script.run();

    payload = script.proposal();
    vm.expectEmit(true, false, false, false);
    emit ChainlinkUpkeepRegistered('AaveArbitrumRobotKeeperV2', 0);

    // Execute proposal
    _executor.execute(address(payload));
  }
}
