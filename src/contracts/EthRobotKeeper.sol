// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {KeeperCompatibleInterface} from 'chainlink-brownie-contracts/KeeperCompatible.sol';
import {IAaveGovernanceV2, IExecutorWithTimelock} from 'aave-address-book/AaveGovernanceV2.sol';
import {IGovernanceRobotKeeper} from '../interfaces/IGovernanceRobotKeeper.sol';

/**
 * @author BGD Labs
 * @dev Aave chainlink keeper-compatible contract for proposal automation:
 * - checks if the proposal state could be moved to queued or executed
 * - moves the proposal to queued and executed if all the conditions are met
 */
contract EthRobotKeeper is IGovernanceRobotKeeper {
  // TODO: add SafeMath

  /**
   * @dev run off-chain, checks if proposals should be moved to queued or executed state
   * @param checkData address of the governance contract
   */
  function checkUpkeep(bytes calldata checkData)
    external
    view
    override
    returns (bool, bytes memory)
  {
    address governanceAddress = abi.decode(checkData, (address));
    IAaveGovernanceV2 governanceV2 = IAaveGovernanceV2(
      governanceAddress
    );

    bytes memory performData;
    uint256 proposalsCount = governanceV2.getProposalsCount();
    uint256 proposalsStartLimit = proposalsCount;

    // iterate from the last proposal till we find an executed proposal
    for (uint proposalId = proposalsCount - 1; proposalId >= 0 ; proposalId--) {
      if (governanceV2.getProposalState(proposalsStartLimit) == IAaveGovernanceV2.ProposalState.Executed) {
        proposalId < 20 ? proposalsStartLimit = 0 : proposalsStartLimit = proposalId - 20;
        break;
      }
    }

    // iterate from an executed proposal minus 20 to be sure
    for (uint i = proposalsStartLimit; i < proposalsCount; i++) {
      if (canProposalBeQueued(i, governanceAddress)) {
        performData = abi.encode(governanceAddress, i, ProposalAction.PerformQueue);
        return (true, performData);
      } else if (canProposalBeExecuted(i, governanceAddress)) {
        performData = abi.encode(governanceAddress, i, ProposalAction.PerformQueue);
        return (true, performData);
      }
    }

    return (false, performData);
  }

  /**
   * @dev if proposal could be queued/executed - executes queue/execute action on the governance contract
   * @param performData address of the governance contract, proposal id, action whether to queue or execute
   */
  function performUpkeep(bytes calldata performData) external override {
    (address governanceAddress, uint256 proposalId, ProposalAction action) = abi.decode(performData, (address, uint256, ProposalAction));
    IAaveGovernanceV2 governanceV2 = IAaveGovernanceV2(
      governanceAddress
    );

    if (action == ProposalAction.PerformQueue) {
      require(canProposalBeQueued(proposalId, governanceAddress), 'INVALID_STATE_FOR_QUEUED');
      governanceV2.queue(proposalId);
    } else if (action == ProposalAction.PerformExecute) {
      require(canProposalBeExecuted(proposalId, governanceAddress), 'INVALID_STATE_FOR_EXECUTED');
      governanceV2.execute(proposalId);
    }
  }

  function canProposalBeQueued(uint256 proposalId, address governanceAddress) internal view returns (bool) {
    IAaveGovernanceV2 governanceV2 = IAaveGovernanceV2(
      governanceAddress
    );
    IAaveGovernanceV2.ProposalWithoutVotes memory proposal = governanceV2.getProposalById(proposalId);
    uint256 delay = proposal.executor.getDelay();
    IAaveGovernanceV2.ProposalState proposalState = governanceV2.getProposalState(proposalId);
    // TODO: Use SafeMath and check logic for delay
    if (proposalState == IAaveGovernanceV2.ProposalState.Succeeded && block.timestamp >= proposal.executionTime + delay) {
      return true;
    }
    return false;
  }

  function canProposalBeExecuted(uint256 proposalId, address governanceAddress) internal view returns (bool) {
    IAaveGovernanceV2 governanceV2 = IAaveGovernanceV2(
      governanceAddress
    );
    IAaveGovernanceV2.ProposalWithoutVotes memory proposal = governanceV2.getProposalById(proposalId);
    IAaveGovernanceV2.ProposalState proposalState = governanceV2.getProposalState(proposalId);
    uint256 GRACE_PERIOD = proposal.executor.GRACE_PERIOD();
    // TODO: Use SafeMath
    if (proposalState == IAaveGovernanceV2.ProposalState.Queued && block.timestamp <= proposal.executionTime + GRACE_PERIOD) {
      return true;
    }
    return false;
  }
}
