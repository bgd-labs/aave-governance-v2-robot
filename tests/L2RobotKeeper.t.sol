// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {L2RobotKeeper} from '../src/contracts/L2RobotKeeper.sol';
import {IExecutorBase} from 'governance-crosschain-bridges/contracts/interfaces/IExecutorBase.sol';
import 'forge-std/console.sol';

contract L2RobotKeeperTest is Test {

  function testSimpleExecutePolygon() public {
    vm.createSelectFork(
      'https://polygon-mainnet.g.alchemy.com/v2/rYCvre87pHXUBPFA0Shbg63H6VVCRZHq',
      39099833 // Feb-09-2023
    );
    L2RobotKeeper l2RobotKeeper = new L2RobotKeeper();

    IExecutorBase bridgeExecutor = IExecutorBase(0xdc9A35B16DB4e126cFeDC41322b3a36454B1F772);
    IExecutorBase.ActionsSetState initialActionsSetState = bridgeExecutor.getCurrentState(13);
    assertEq(uint256(initialActionsSetState), 0);
    console.log('Initial State of ActionsSet 13', uint256(initialActionsSetState));

    (bool shouldRunKeeper, bytes memory performData) = l2RobotKeeper.checkUpkeep(abi.encode(address(bridgeExecutor)));

    if (shouldRunKeeper) {
      l2RobotKeeper.performUpkeep(performData);
      IExecutorBase.ActionsSetState finalActionsSetState = bridgeExecutor.getCurrentState(13);
      assertEq(uint256(finalActionsSetState), 1);
      console.log('Final State of ActionsSet 13 after automation', uint256(finalActionsSetState));
    }
  }

  function testSimpleExecuteArbitrum() public {
    vm.createSelectFork(
      'https://arb-mainnet.g.alchemy.com/v2/4b5zYcMERmrGAlfneBy2n21k49HK1a-O',
      49297907 // Dec-28-2022
    );
    L2RobotKeeper l2RobotKeeper = new L2RobotKeeper();

    IExecutorBase bridgeExecutor = IExecutorBase(0x7d9103572bE58FfE99dc390E8246f02dcAe6f611);
    IExecutorBase.ActionsSetState initialActionsSetState = bridgeExecutor.getCurrentState(0);
    assertEq(uint256(initialActionsSetState), 0);
    console.log('Initial State of ActionsSet 0', uint256(initialActionsSetState));

    (bool shouldRunKeeper, bytes memory performData) = l2RobotKeeper.checkUpkeep(abi.encode(address(bridgeExecutor)));

    if (shouldRunKeeper) {
      l2RobotKeeper.performUpkeep(performData);
      IExecutorBase.ActionsSetState finalActionsSetState = bridgeExecutor.getCurrentState(0);
      assertEq(uint256(finalActionsSetState), 1);
      console.log('Final State of ActionsSet 0 after automation', uint256(finalActionsSetState));
    }
  }
}
