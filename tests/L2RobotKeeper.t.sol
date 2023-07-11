// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {L2RobotKeeper} from '../src/contracts/L2RobotKeeper.sol';
import {IExecutorBase} from 'governance-crosschain-bridges/contracts/interfaces/IExecutorBase.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import 'forge-std/console.sol';

contract L2RobotKeeperTest is Test {
  function testSimpleExecutePolygon() public {
    vm.createSelectFork(
      'polygon',
      39099833 // Feb-09-2023
    );
    IExecutorBase bridgeExecutor = IExecutorBase(AaveGovernanceV2.POLYGON_BRIDGE_EXECUTOR);
    L2RobotKeeper l2RobotKeeper = new L2RobotKeeper(address(bridgeExecutor));

    IExecutorBase.ActionsSetState actionsSetState = bridgeExecutor.getCurrentState(13);
    assertEq(uint256(actionsSetState), 0);
    console.log('Initial State of ActionsSet 13: Queued', uint256(actionsSetState));

    checkAndPerformUpKeep(l2RobotKeeper);

    actionsSetState = bridgeExecutor.getCurrentState(13);
    assertEq(uint256(actionsSetState), 1);
    console.log(
      'Final State of ActionsSet 13 after automation: Executed',
      uint256(actionsSetState)
    );
  }

  function testSimpleExecuteArbitrum() public {
    vm.createSelectFork(
      'arbitrum',
      49297907 // Dec-28-2022
    );
    IExecutorBase bridgeExecutor = IExecutorBase(AaveGovernanceV2.ARBITRUM_BRIDGE_EXECUTOR);
    L2RobotKeeper l2RobotKeeper = new L2RobotKeeper(address(bridgeExecutor));

    IExecutorBase.ActionsSetState actionsSetState = bridgeExecutor.getCurrentState(0);
    assertEq(uint256(actionsSetState), 0);
    console.log('Initial State of ActionsSet 0: Queued', uint256(actionsSetState));

    checkAndPerformUpKeep(l2RobotKeeper);

    actionsSetState = bridgeExecutor.getCurrentState(0);
    assertEq(uint256(actionsSetState), 1);
    console.log('Final State of ActionsSet 0 after automation: Executed', uint256(actionsSetState));
  }

  function testSimpleExecuteOptimism() public {
    vm.createSelectFork(
      'optimism',
      84422556 // May-10-2023
    );
    IExecutorBase bridgeExecutor = IExecutorBase(AaveGovernanceV2.OPTIMISM_BRIDGE_EXECUTOR);
    L2RobotKeeper l2RobotKeeper = new L2RobotKeeper(address(bridgeExecutor));

    IExecutorBase.ActionsSetState actionsSetState = bridgeExecutor.getCurrentState(9);
    assertEq(uint256(actionsSetState), 0);
    console.log('Initial State of ActionsSet 9: Queued', uint256(actionsSetState));

    checkAndPerformUpKeep(l2RobotKeeper);

    actionsSetState = bridgeExecutor.getCurrentState(9);
    assertEq(uint256(actionsSetState), 1);
    console.log('Final State of ActionsSet 9 after automation: Executed', uint256(actionsSetState));
  }

  function testDisable() public {
    vm.createSelectFork(
      'optimism',
      84422556 // May-10-2023
    );
    IExecutorBase bridgeExecutor = IExecutorBase(AaveGovernanceV2.OPTIMISM_BRIDGE_EXECUTOR);
    L2RobotKeeper l2RobotKeeper = new L2RobotKeeper(address(bridgeExecutor));

    vm.startPrank(l2RobotKeeper.owner());
    l2RobotKeeper.toggleDisableAutomationById(9);
    vm.stopPrank();

    IExecutorBase.ActionsSetState actionsSetState = bridgeExecutor.getCurrentState(9);
    assertEq(uint256(actionsSetState), 0);
    console.log('Initial State of ActionsSet 9: Queued', uint256(actionsSetState));

    checkAndPerformUpKeep(l2RobotKeeper);

    actionsSetState = bridgeExecutor.getCurrentState(9);
    assertEq(uint256(actionsSetState), 0);
    console.log('Final State of ActionsSet 9 after automation: Queued', uint256(actionsSetState));
  }

  function checkAndPerformUpKeep(L2RobotKeeper l2RobotKeeper) private {
    (bool shouldRunKeeper, bytes memory performData) = l2RobotKeeper.checkUpkeep('');
    if (shouldRunKeeper) {
      l2RobotKeeper.performUpkeep(performData);
    }
  }
}
