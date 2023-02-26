// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';
import {L2RobotKeeper} from '../src/contracts/L2RobotKeeper.sol';
import {IExecutorBase} from 'governance-crosschain-bridges/contracts/interfaces/IExecutorBase.sol';
import {ProposalPayloadPolygonRobot} from '../src/proposal/ProposalPayloadPolygonRobot.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';

contract Deploy is Script {
  address public constant GUARDIAN = 0xa35b76E4935449E33C56aB24b23fcd3246f13470;
  ProposalPayloadPolygonRobot public proposal;
  L2RobotKeeper public keeper;

  function run() external {
    vm.startBroadcast();
    IExecutorBase bridgeExecutor = IExecutorBase(AaveGovernanceV2.POLYGON_BRIDGE_EXECUTOR);
    new L2RobotKeeper(bridgeExecutor);
    keeper = new L2RobotKeeper(bridgeExecutor);
    keeper.transferOwnership(GUARDIAN);

    // create proposal here and pass the keeper address and the link amount to fund
    proposal = new ProposalPayloadPolygonRobot(address(keeper), 100 ether);

    console.log('Polygon keeper address', address(keeper));
    console.log('Polygon payload address', address(proposal));
    vm.stopBroadcast();
  }
}
