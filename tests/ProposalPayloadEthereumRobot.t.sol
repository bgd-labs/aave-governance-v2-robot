// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Deploy} from '../scripts/DeployEthereumPayload.s.sol';
import {ProposalPayloadEthereumRobot} from '../src/proposal/ProposalPayloadEthereumRobot.sol';
import {TestWithExecutor} from 'aave-helpers/GovHelpers.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';

contract ProposalPayloadEthRobotTest is TestWithExecutor {
  ProposalPayloadEthereumRobot public payload;

  event ChainlinkUpkeepRegistered(string indexed name, uint256 indexed upkeedId);

  function setUp() public {
    vm.createSelectFork('mainnet', 17285700);
    _selectPayloadExecutor(AaveGovernanceV2.SHORT_EXECUTOR);
  }

  function testExecuteProposalEth() public {
    // deploy all contracts
    Deploy script = new Deploy();
    script.run();

    payload = script.payload();
    vm.expectEmit(true, false, false, false);
    emit ChainlinkUpkeepRegistered('AaveEthRobotKeeperV2', 0);

    // Execute proposal
    _executor.execute(address(payload));
  }
}
