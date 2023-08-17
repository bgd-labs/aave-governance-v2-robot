// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';
import {ProposalPayloadPolygonRobot} from '../src/proposal/ProposalPayloadPolygonRobot.sol';

contract Deploy is Script {
  ProposalPayloadPolygonRobot public proposal;

  address public constant ETHEREUM_ROBOT_OPERATOR = 0x4e8984D11A47Ff89CD67c7651eCaB6C00a74B4A9;
  uint256 public constant KEEPER_ID = 5270433258472149004463739312507691937285233476849983113005055156517680660709;
  uint256 public constant AMOUNT_TO_FUND = 25 ether;

  function run() external {
    vm.startBroadcast();

    proposal = new ProposalPayloadPolygonRobot(
      KEEPER_ID,
      ETHEREUM_ROBOT_OPERATOR,
      AMOUNT_TO_FUND
    );

    console.log('Polygon payload address', address(proposal));
    vm.stopBroadcast();
  }
}
