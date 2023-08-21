// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Deploy} from '../scripts/DeployArbitrumPayload.s.sol';
import {ProposalPayloadArbitrumRobot} from '../src/proposal/ProposalPayloadArbitrumRobot.sol';
import {AaveV3ArbitrumAssets} from 'aave-address-book/AaveV3Arbitrum.sol';
import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {GovHelpers} from 'aave-helpers/GovHelpers.sol';
import {Test} from 'forge-std/Test.sol';

contract ProposalPayloadArbitrumRobotTest is Test {
  ProposalPayloadArbitrumRobot public payload;
  event KeeperRefilled(uint256 indexed id, address indexed from, uint96 indexed amount);

  function setUp() public {
    vm.createSelectFork('arbitrum', 121961827);
  }

  function testExecuteProposalArbitrum() public {
    Deploy script = new Deploy();
    script.run();

    payload = script.payload();
    vm.expectEmit(true, true, true, false);
    emit KeeperRefilled(script.KEEPER_ID(), AaveGovernanceV2.ARBITRUM_BRIDGE_EXECUTOR, uint96(script.AMOUNT_TO_FUND()));

    // Execute proposal
    GovHelpers.executePayload(vm, address(payload), AaveGovernanceV2.ARBITRUM_BRIDGE_EXECUTOR);

    assertEq(IERC20(AaveV3ArbitrumAssets.LINK_UNDERLYING).balanceOf(AaveGovernanceV2.SHORT_EXECUTOR), 0);
    assertEq(IERC20(AaveV3ArbitrumAssets.LINK_A_TOKEN).balanceOf(AaveGovernanceV2.SHORT_EXECUTOR), 0);
  }
}
