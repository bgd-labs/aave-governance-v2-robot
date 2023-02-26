// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {EthRobotKeeper} from '../src/contracts/EthRobotKeeper.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';

contract Deploy is Script {
  EthRobotKeeper public keeper;
  address public constant GUARDIAN = 0xa35b76E4935449E33C56aB24b23fcd3246f13470;

  function run() external {
    vm.startBroadcast();
    keeper = new EthRobotKeeper(AaveGovernanceV2.GOV);
    keeper.transferOwnership(GUARDIAN);
    vm.stopBroadcast();
  }
}
