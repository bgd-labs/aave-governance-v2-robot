// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';
import {AaveCLRobotOperator} from '../src/contracts/AaveCLRobotOperator.sol';
import {ProposalPayloadOptimismRobot} from '../src/proposal/ProposalPayloadOptimismRobot.sol';
import {L2RobotKeeper} from '../src/contracts/L2RobotKeeper.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {AaveV3Optimism, AaveV3OptimismAssets} from 'aave-address-book/AaveV3Optimism.sol';

contract Deploy is Script {
  L2RobotKeeper public keeper;
  AaveCLRobotOperator public aaveCLRobotOperator;
  ProposalPayloadOptimismRobot public payload;
  address public constant KEEPER_REGISTRY = 0x75c0530885F385721fddA23C539AF3701d6183D4;
  address public constant KEEPER_REGISTRAR = 0x4F3AF332A30973106Fe146Af0B4220bBBeA748eC;
  address public constant MAINTENANCE_ADMIN = 0xe3FD707583932a99513a5c65c8463De769f5DAdF;

  function run() external {
    vm.startBroadcast();
    // deploy the robot operator
    aaveCLRobotOperator = new AaveCLRobotOperator(
      AaveV3OptimismAssets.LINK_UNDERLYING,
      KEEPER_REGISTRY,
      KEEPER_REGISTRAR,
      address(AaveV3Optimism.COLLECTOR),
      AaveGovernanceV2.OPTIMISM_BRIDGE_EXECUTOR,
      MAINTENANCE_ADMIN
    );
    // deploy the keeper
    keeper = new L2RobotKeeper(
      AaveGovernanceV2.OPTIMISM_BRIDGE_EXECUTOR,
      address(aaveCLRobotOperator)
    );

    // deploy the payload
    payload = new ProposalPayloadOptimismRobot(
      address(keeper),
      address(aaveCLRobotOperator),
      50 ether
    );

    console.log('Optimism keeper address', address(keeper));
    console.log('Optimism operator address', address(aaveCLRobotOperator));
    console.log('Optimism payload address', address(payload));
    vm.stopBroadcast();
  }
}
