// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {L2RobotKeeper} from '../src/contracts/L2RobotKeeper.sol';
import {IExecutorBase} from 'governance-crosschain-bridges/contracts/interfaces/IExecutorBase.sol';

contract Deploy is Script {
  function run() external {
    vm.startBroadcast();
    IExecutorBase bridgeExecutor = IExecutorBase(0xdc9A35B16DB4e126cFeDC41322b3a36454B1F772);
    new L2RobotKeeper(bridgeExecutor);
    vm.stopBroadcast();
  }
}
