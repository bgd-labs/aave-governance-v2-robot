// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Deploy} from '../scripts/DeployEthRobotKeeper.s.sol';
import {ProposalPayloadEthRobot} from '../src/proposal/ProposalPayloadEthRobot.sol';
import {TestWithExecutor} from 'aave-helpers/GovHelpers.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';

contract ProposalPayloadEthRobotTest is TestWithExecutor {
  ProposalPayloadEthRobot public payload;

  event ChainlinkUpkeepRegistered(string indexed name, uint256 indexed upkeedId);

  function setUp() public {
    vm.createSelectFork(
      'mainnet',
      16613098 // Feb-12-2023
    );
    _selectPayloadExecutor(AaveGovernanceV2.SHORT_EXECUTOR);
  }

  function testExecuteProposalEth() public {
    // deploy all contracts
    Deploy script = new Deploy();
    script.run();

    payload = script.proposal();
    vm.expectEmit(true, false, false, false);
    emit ChainlinkUpkeepRegistered('AaveEthRobotKeeperV2', 0);

    // Execute proposal
    _executor.execute(address(payload));
  }
}
