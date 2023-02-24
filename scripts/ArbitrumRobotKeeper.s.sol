// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {L2RobotKeeper} from '../src/contracts/L2RobotKeeper.sol';
import {IExecutorBase} from 'governance-crosschain-bridges/contracts/interfaces/IExecutorBase.sol';

contract Deploy is Script {
  function run() external {
    vm.startBroadcast();
    IExecutorBase bridgeExecutor = IExecutorBase(0x7d9103572bE58FfE99dc390E8246f02dcAe6f611);
    new L2RobotKeeper(bridgeExecutor);
    vm.stopBroadcast();
  }
}
