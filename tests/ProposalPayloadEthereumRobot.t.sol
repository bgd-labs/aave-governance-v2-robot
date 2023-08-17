// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Deploy} from '../scripts/DeployEthereumPayload.s.sol';
import {ProposalPayloadEthereumRobot} from '../src/proposal/ProposalPayloadEthereumRobot.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {GovHelpers} from 'aave-helpers/GovHelpers.sol';
import {Test} from 'forge-std/Test.sol';

contract ProposalPayloadEthRobotTest is Test {
  ProposalPayloadEthereumRobot public payload;
  event KeeperRefilled(uint256 indexed id, address indexed from, uint96 indexed amount);

  function setUp() public {
    vm.createSelectFork('mainnet', 17932618);
  }

  function testExecuteProposalEth() public {
    Deploy script = new Deploy();
    script.run();

    payload = script.payload();
    vm.expectEmit(true, true, true, false);
    emit KeeperRefilled(script.KEEPER_ID(), AaveGovernanceV2.SHORT_EXECUTOR, uint96(script.AMOUNT_TO_FUND()));

    // Execute proposal
    GovHelpers.executePayload(vm, address(payload), AaveGovernanceV2.SHORT_EXECUTOR);
  }
}
