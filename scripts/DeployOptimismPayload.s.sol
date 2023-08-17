// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';
import {ProposalPayloadOptimismRobot} from '../src/proposal/ProposalPayloadOptimismRobot.sol';

contract Deploy is Script {
  ProposalPayloadOptimismRobot public payload;

  address public constant ETHEREUM_ROBOT_OPERATOR = 0x4f830bc2DdaC99307a3709c85F7533842BdA7c63;
  uint256 public constant KEEPER_ID = 14511291151503490097406614071718050938575520605993697066624566563051111599185;
  uint256 public constant AMOUNT_TO_FUND = 25 ether;

  function run() external {
    vm.startBroadcast();

    payload = new ProposalPayloadOptimismRobot(
      KEEPER_ID,
      ETHEREUM_ROBOT_OPERATOR,
      AMOUNT_TO_FUND
    );

    console.log('Optimism payload address', address(payload));
    vm.stopBroadcast();
  }
}
