// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';
import {L2RobotKeeper} from '../src/contracts/L2RobotKeeper.sol';
import {AaveCLRobotOperator} from '../src/contracts/AaveCLRobotOperator.sol';
import {ProposalPayloadPolygonRobot} from '../src/proposal/ProposalPayloadPolygonRobot.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {AaveV3Polygon, AaveV3PolygonAssets} from 'aave-address-book/AaveV3Polygon.sol';

contract Deploy is Script {
  ProposalPayloadPolygonRobot public proposal;
  L2RobotKeeper public keeper;
  AaveCLRobotOperator public aaveCLRobotOperator;
  address public constant KEEPER_REGISTRY = 0x02777053d6764996e594c3E88AF1D58D5363a2e6;
  address public constant KEEPER_REGISTRAR = 0xDb8e8e2ccb5C033938736aa89Fe4fa1eDfD15a1d;
  address public constant MAINTENANCE_ADMIN = 0xe3FD707583932a99513a5c65c8463De769f5DAdF;
  address public constant ERC677_LINK = 0xb0897686c545045aFc77CF20eC7A532E3120E0F1;

  function run() external {
    vm.startBroadcast();
    // deploy the robot operator
    aaveCLRobotOperator = new AaveCLRobotOperator(
      ERC677_LINK,
      KEEPER_REGISTRY,
      KEEPER_REGISTRAR,
      address(AaveV3Polygon.COLLECTOR),
      AaveGovernanceV2.POLYGON_BRIDGE_EXECUTOR,
      MAINTENANCE_ADMIN
    );
    keeper = new L2RobotKeeper(
      AaveGovernanceV2.POLYGON_BRIDGE_EXECUTOR
    );

    // create proposal here and pass the keeper address and the link amount to fund
    proposal = new ProposalPayloadPolygonRobot(
      address(keeper),
      address(aaveCLRobotOperator),
      30 ether
    );

    console.log('Polygon keeper address', address(keeper));
    console.log('Polygon operator address', address(aaveCLRobotOperator));
    console.log('Polygon payload address', address(proposal));
    vm.stopBroadcast();
  }
}
