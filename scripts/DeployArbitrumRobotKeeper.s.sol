// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';
import {ProposalPayloadArbitrumRobot} from '../src/proposal/ProposalPayloadArbitrumRobot.sol';
import {L2RobotKeeper} from '../src/contracts/L2RobotKeeper.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {IExecutorBase} from 'governance-crosschain-bridges/contracts/interfaces/IExecutorBase.sol';

contract Deploy is Script {
  L2RobotKeeper public keeper;
  ProposalPayloadArbitrumRobot public proposal;
  address public constant GUARDIAN = 0xa35b76E4935449E33C56aB24b23fcd3246f13470;

  function run() external {
    vm.startBroadcast();
    IExecutorBase bridgeExecutor = IExecutorBase(AaveGovernanceV2.ARBITRUM_BRIDGE_EXECUTOR);
    keeper = new L2RobotKeeper(bridgeExecutor);
    keeper.transferOwnership(GUARDIAN);

    // create proposal here and pass the keeper address and the link amount to fund
    proposal = new ProposalPayloadArbitrumRobot(address(keeper), 50 ether);

    console.log('Arbitrum keeper address', address(keeper));
    console.log('Arbitrum payload address', address(proposal));
    vm.stopBroadcast();
  }
}
