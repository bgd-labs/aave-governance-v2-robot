// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';
import {EthRobotKeeper} from '../src/contracts/EthRobotKeeper.sol';
import {AaveCLRobotOperator} from '../src/contracts/AaveCLRobotOperator.sol';
import {ProposalPayloadEthereumRobot} from '../src/proposal/ProposalPayloadEthereumRobot.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';

contract Deploy is Script {
  EthRobotKeeper public keeper;
  AaveCLRobotOperator public aaveCLRobotOperator;
  ProposalPayloadEthereumRobot public payload;
  address public constant MAINTENANCE_ADMIN = 0xe3FD707583932a99513a5c65c8463De769f5DAdF;

  function run() external {
    vm.startBroadcast();
    // deploy the robot operator
    aaveCLRobotOperator = new AaveCLRobotOperator(
      AaveV3EthereumAssets.LINK_UNDERLYING,
      address(AaveV3Ethereum.COLLECTOR),
      AaveGovernanceV2.SHORT_EXECUTOR,
      MAINTENANCE_ADMIN
    );
    // deploy the keeper
    keeper = new EthRobotKeeper(address(AaveGovernanceV2.GOV), address(aaveCLRobotOperator));

    // deploy the payload
    payload = new ProposalPayloadEthereumRobot(address(keeper), address(aaveCLRobotOperator), 1000 ether);

    console.log('Ethereum keeper address', address(keeper));
    console.log('Ethereum operator address', address(aaveCLRobotOperator));
    console.log('Ethereum payload address', address(payload));
    vm.stopBroadcast();
  }
}
