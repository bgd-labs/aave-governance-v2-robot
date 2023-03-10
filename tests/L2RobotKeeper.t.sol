// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {L2RobotKeeper} from '../src/contracts/L2RobotKeeper.sol';
import {IExecutorBase} from 'governance-crosschain-bridges/contracts/interfaces/IExecutorBase.sol';
import 'forge-std/console.sol';

contract L2RobotKeeperTest is Test {
  function testSimpleExecutePolygon() public {
    vm.createSelectFork(
      'polygon',
      39099833 // Feb-09-2023
    );
    IExecutorBase bridgeExecutor = IExecutorBase(0xdc9A35B16DB4e126cFeDC41322b3a36454B1F772);
    L2RobotKeeper l2RobotKeeper = new L2RobotKeeper(bridgeExecutor);

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
    IExecutorBase bridgeExecutor = IExecutorBase(0x7d9103572bE58FfE99dc390E8246f02dcAe6f611);
    L2RobotKeeper l2RobotKeeper = new L2RobotKeeper(bridgeExecutor);

    IExecutorBase.ActionsSetState actionsSetState = bridgeExecutor.getCurrentState(0);
    assertEq(uint256(actionsSetState), 0);
    console.log('Initial State of ActionsSet 0: Queued', uint256(actionsSetState));

    checkAndPerformUpKeep(l2RobotKeeper);

    actionsSetState = bridgeExecutor.getCurrentState(0);
    assertEq(uint256(actionsSetState), 1);
    console.log('Final State of ActionsSet 0 after automation: Executed', uint256(actionsSetState));
  }

  function checkAndPerformUpKeep(L2RobotKeeper l2RobotKeeper) private {
    (bool shouldRunKeeper, bytes memory performData) = l2RobotKeeper.checkUpkeep('');
    if (shouldRunKeeper) {
      l2RobotKeeper.performUpkeep(performData);
    }
  }
}
