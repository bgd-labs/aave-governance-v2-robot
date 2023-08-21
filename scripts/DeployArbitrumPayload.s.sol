// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';
import {ProposalPayloadArbitrumRobot} from '../src/proposal/ProposalPayloadArbitrumRobot.sol';

contract Deploy is Script {
  ProposalPayloadArbitrumRobot public payload;

  address public constant ARBITRUM_ROBOT_OPERATOR = 0xb0A73671C97BAC9Ba899CD1a23604Fd2278cD02A;
  uint256 public constant KEEPER_ID = 99910557623747840434738249049159754336730253966084942174349501874329868147502;
  uint256 public constant AMOUNT_TO_FUND = 25 ether;

  function run() external {
    vm.startBroadcast();
    payload = new ProposalPayloadArbitrumRobot(
      KEEPER_ID,
      ARBITRUM_ROBOT_OPERATOR,
      AMOUNT_TO_FUND
    );
    console.log('Arbitrum payload address', address(payload));
    vm.stopBroadcast();
  }
}
