// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';
import {AaveCLRobotOperator} from '../src/contracts/AaveCLRobotOperator.sol';
import {ProposalPayloadArbitrumRobot} from '../src/proposal/ProposalPayloadArbitrumRobot.sol';
import {L2RobotKeeper} from '../src/contracts/L2RobotKeeper.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {IExecutorBase} from 'governance-crosschain-bridges/contracts/interfaces/IExecutorBase.sol';
import {AaveV3Arbitrum, AaveV3ArbitrumAssets} from 'aave-address-book/AaveV3Arbitrum.sol';

contract Deploy is Script {
  L2RobotKeeper public keeper;
  AaveCLRobotOperator public aaveCLRobotOperator;
  ProposalPayloadArbitrumRobot public payload;
  address public constant MAINTENANCE_ADMIN = 0xe3FD707583932a99513a5c65c8463De769f5DAdF;

  function run() external {
    vm.startBroadcast();
    // deploy the robot operator
    aaveCLRobotOperator = new AaveCLRobotOperator(
      AaveV3ArbitrumAssets.LINK_UNDERLYING,
      address(AaveV3Arbitrum.COLLECTOR),
      AaveGovernanceV2.ARBITRUM_BRIDGE_EXECUTOR,
      MAINTENANCE_ADMIN
    );
    // deploy the keeper
    keeper = new L2RobotKeeper(
      AaveGovernanceV2.ARBITRUM_BRIDGE_EXECUTOR,
      address(aaveCLRobotOperator)
    );

    // deploy the payload
    payload = new ProposalPayloadArbitrumRobot(
      address(keeper),
      address(aaveCLRobotOperator),
      50 ether
    );

    console.log('Arbitrum keeper address', address(keeper));
    console.log('Arbitrum operator address', address(aaveCLRobotOperator));
    console.log('Arbitrum payload address', address(payload));
    vm.stopBroadcast();
  }
}
