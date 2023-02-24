// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {EthRobotKeeper} from '../src/contracts/EthRobotKeeper.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';

contract Deploy is Script {
  function run() external {
    vm.startBroadcast();
    new EthRobotKeeper(AaveGovernanceV2.GOV);
    vm.stopBroadcast();
  }
}
