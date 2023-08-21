// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Deploy} from '../scripts/DeployEthereumPayload.s.sol';
import {ProposalPayloadEthereumRobot} from '../src/proposal/ProposalPayloadEthereumRobot.sol';
import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {AaveV2EthereumAssets} from 'aave-address-book/AaveV2Ethereum.sol';
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
    uint256 recepientBalanceBefore = IERC20(AaveV2EthereumAssets.LINK_UNDERLYING).balanceOf(payload.BGD_RECIPIENT());

    vm.expectEmit(true, true, true, false);
    emit KeeperRefilled(script.KEEPER_ID(), AaveGovernanceV2.SHORT_EXECUTOR, uint96(script.AMOUNT_TO_FUND()));

    // Execute proposal
    GovHelpers.executePayload(vm, address(payload), AaveGovernanceV2.SHORT_EXECUTOR);

    uint256 recepientBalanceAfter = IERC20(AaveV2EthereumAssets.LINK_UNDERLYING).balanceOf(payload.BGD_RECIPIENT());
    assertEq(recepientBalanceAfter - recepientBalanceBefore, payload.LINK_AMOUNT_TO_BGD());

    assertEq(IERC20(AaveV2EthereumAssets.LINK_UNDERLYING).balanceOf(AaveGovernanceV2.SHORT_EXECUTOR), 0);
    assertEq(IERC20(AaveV2EthereumAssets.LINK_A_TOKEN).balanceOf(AaveGovernanceV2.SHORT_EXECUTOR), 0);
  }
}
