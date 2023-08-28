// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';
import {ProposalPayloadEthereumRobot} from '../src/proposal/ProposalPayloadEthereumRobot.sol';

contract Deploy is Script {
  ProposalPayloadEthereumRobot public payload;

  address public constant ETHEREUM_ROBOT_OPERATOR = 0x020E452b463568f55BAc6Dc5aFC8F0B62Ea5f0f3;
  uint256 public constant KEEPER_ID = 38708010855340815800266444206792387479170521527111639306025178205742164078384;
  uint256 public constant AMOUNT_TO_FUND = 600 ether;

  function run() external {
    vm.startBroadcast();

    payload = new ProposalPayloadEthereumRobot(
      KEEPER_ID,
      ETHEREUM_ROBOT_OPERATOR,
      AMOUNT_TO_FUND
    );

    console.log('Ethereum payload address', address(payload));
    vm.stopBroadcast();
  }
}
