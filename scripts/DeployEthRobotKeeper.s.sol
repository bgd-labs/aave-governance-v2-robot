// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';
import {EthRobotKeeper} from '../src/contracts/EthRobotKeeper.sol';
import {ProposalPayloadEthRobot} from '../src/proposal/ProposalPayloadEthRobot.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';

contract Deploy is Script {
  EthRobotKeeper public keeper;
  ProposalPayloadEthRobot public proposal;
  address public constant GUARDIAN = 0xa35b76E4935449E33C56aB24b23fcd3246f13470;

  function run() external {
    vm.startBroadcast();
    keeper = new EthRobotKeeper(address(AaveGovernanceV2.GOV), address(0));

    // create proposal here and pass the keeper address and the link amount to fund
    proposal = new ProposalPayloadEthRobot(address(keeper), 50 ether);

    console.log('Ethereum keeper address', address(keeper));
    console.log('Ethereum payload address', address(proposal));
    vm.stopBroadcast();
  }
}
