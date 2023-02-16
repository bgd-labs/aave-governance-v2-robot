// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {KeeperCompatibleInterface} from 'chainlink-brownie-contracts/KeeperCompatible.sol';

interface IGovernanceRobotKeeper is KeeperCompatibleInterface{

    enum ProposalAction {
        PerformQueue,
        PerformExecute
    }
}
