// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';
import {AaveCLRobotOperator} from '../src/contracts/AaveCLRobotOperator.sol';
import {AaveV3Bnb} from 'aave-address-book/AaveV3Bnb.sol';

contract Deploy is Script {
  AaveCLRobotOperator public operator;
  address constant REGISTRY = 0x02777053d6764996e594c3E88AF1D58D5363a2e6;
  address constant REGISTRAR = 0xDb8e8e2ccb5C033938736aa89Fe4fa1eDfD15a1d;
  address constant LINK_TOKEN = 0x404460C6A5EdE2D891e8297795264fDe62ADBB75;

  function run() external {
    vm.startBroadcast();
    operator = new AaveCLRobotOperator(
      LINK_TOKEN,
      REGISTRY,
      REGISTRAR,
      address(AaveV3Bnb.COLLECTOR), // WITHDRAW ADDRESS
      0xe3FD707583932a99513a5c65c8463De769f5DAdF // ROBOT GUARDIAN
    );
    console.log('Bnb operator address', address(operator));
    vm.stopBroadcast();
  }
}
