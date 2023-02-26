// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {L2RobotKeeper} from '../src/contracts/L2RobotKeeper.sol';
import {IExecutorBase} from 'governance-crosschain-bridges/contracts/interfaces/IExecutorBase.sol';

contract Deploy is Script {
  L2RobotKeeper public keeper;
  address public constant GUARDIAN = 0xa35b76E4935449E33C56aB24b23fcd3246f13470;

  function run() external {
    vm.startBroadcast();
    IExecutorBase bridgeExecutor = IExecutorBase(0x7d9103572bE58FfE99dc390E8246f02dcAe6f611);
    keeper = new L2RobotKeeper(bridgeExecutor);
    keeper.transferOwnership(GUARDIAN);
    vm.stopBroadcast();
  }
}
