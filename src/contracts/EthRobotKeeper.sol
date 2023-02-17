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

    uint256 proposalsCount = governanceV2.getProposalsCount();
    uint256 proposalsStartLimit = 0;

    // iterate from the last proposal till we find an executed proposal
    for (uint proposalId = proposalsCount - 1; proposalId >= 0; proposalId--) {
      if (governanceV2.getProposalState(proposalId) == IAaveGovernanceV2.ProposalState.Executed) {
        proposalId < 20 ? proposalsStartLimit = 0 : proposalsStartLimit = proposalId - 20;
        break;
      }
    }

    // iterate from an executed proposal minus 20 to be sure
    for (uint i = proposalsStartLimit; i < proposalsCount; i++) {
      if (canProposalBeQueued(i, governanceAddress)) {
        bytes memory performData = abi.encode(governanceAddress, i, ProposalAction.PerformQueue);
        return (true, performData);
      } else if (canProposalBeExecuted(i, governanceAddress)) {
        bytes memory performData = abi.encode(governanceAddress, i, ProposalAction.PerformExecute);
        return (true, performData);
      }
    }

    return (false, checkData);
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
      require(canProposalBeQueued(proposalId, governanceAddress), 'INVALID_STATE_FOR_QUEUE');
      governanceV2.queue(proposalId);
    } else if (action == ProposalAction.PerformExecute) {
      require(canProposalBeExecuted(proposalId, governanceAddress), 'INVALID_STATE_FOR_EXECUTE');
      governanceV2.execute(proposalId);
    }
  }

  function canProposalBeQueued(uint256 proposalId, address governanceAddress) internal view returns (bool) {
    IAaveGovernanceV2 governanceV2 = IAaveGovernanceV2(
      governanceAddress
    );
    IAaveGovernanceV2.ProposalState proposalState = governanceV2.getProposalState(proposalId);
    if (proposalState == IAaveGovernanceV2.ProposalState.Succeeded) {
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
    // TODO: Use SafeMath
    if (
      proposalState == IAaveGovernanceV2.ProposalState.Queued && 
      block.timestamp >= proposal.executionTime && 
      block.timestamp <= proposal.executionTime + proposal.executor.GRACE_PERIOD()
    ) {
      return true;
    }
    return false;
  }
}
