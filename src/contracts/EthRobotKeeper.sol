// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {KeeperCompatibleInterface} from 'chainlink-brownie-contracts/KeeperCompatible.sol';
import {IAaveGovernanceV2, IExecutorWithTimelock} from 'aave-address-book/AaveGovernanceV2.sol';
import {IProposalValidator} from '../interfaces/IProposalValidator.sol';
import {IGovernanceRobotKeeper} from '../interfaces/IGovernanceRobotKeeper.sol';

/**
 * @author BGD Labs
 * @dev Aave chainlink keeper-compatible contract for proposal automation:
 * - checks if the proposal state could be moved to queued, executed or cancelled
 * - moves the proposal to queued/executed/cancelled if all the conditions are met
 */
contract EthRobotKeeper is IGovernanceRobotKeeper {

  /**
   * @dev run off-chain, checks if proposals should be moved to queued, executed or cancelled state
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
    for (uint256 proposalId = proposalsCount - 1; proposalId >= 0; proposalId--) {
      if (governanceV2.getProposalState(proposalId) == IAaveGovernanceV2.ProposalState.Executed) {
        proposalId < 20 ? proposalsStartLimit = 0 : proposalsStartLimit = proposalId - 20;
        break;
      }
    }

    // iterate from an executed proposal minus 20 to be sure
    for (uint256 proposalId = proposalsStartLimit; proposalId < proposalsCount; proposalId++) {

      IAaveGovernanceV2.ProposalWithoutVotes memory proposal = governanceV2.getProposalById(proposalId);
      IAaveGovernanceV2.ProposalState proposalState = governanceV2.getProposalState(proposalId);

      if (canProposalBeQueued(proposalState)) {
        bytes memory performData = abi.encode(governanceV2, proposalId, ProposalAction.PerformQueue);
        return (true, performData);
      } else if (canProposalBeExecuted(proposalState, proposal)) {
        bytes memory performData = abi.encode(governanceV2, proposalId, ProposalAction.PerformExecute);
        return (true, performData);
      } else if (canProposalBeCancelled(proposalState, proposal, governanceV2)) {
        bytes memory performData = abi.encode(governanceV2, proposalId, ProposalAction.PerformCancel);
        return (true, performData);
      }
    }

    return (false, checkData);
  }

  /**
   * @dev if proposal could be queued/executed/cancelled - executes queue/cancel/execute action on the governance contract
   * @param performData governance contract, proposal id, action whether to queue, execute or cancel
   */
  function performUpkeep(bytes calldata performData) external override {
    (IAaveGovernanceV2 governanceV2, uint256 proposalId, ProposalAction action) = abi.decode(performData, (IAaveGovernanceV2, uint256, ProposalAction));

    IAaveGovernanceV2.ProposalWithoutVotes memory proposal = governanceV2.getProposalById(proposalId);
    IAaveGovernanceV2.ProposalState proposalState = governanceV2.getProposalState(proposalId);

    if (action == ProposalAction.PerformQueue) {
      require(canProposalBeQueued(proposalState), 'INVALID_STATE_FOR_QUEUE');
      governanceV2.queue(proposalId);
    } else if (action == ProposalAction.PerformExecute) {
      require(canProposalBeExecuted(proposalState, proposal), 'INVALID_STATE_FOR_EXECUTE');
      governanceV2.execute(proposalId);
    } else if (action == ProposalAction.PerformCancel) {
      require(canProposalBeCancelled(proposalState, proposal, governanceV2), 'INVALID_STATE_FOR_CANCEL');
      governanceV2.cancel(proposalId);
    }
  }

  function canProposalBeQueued(IAaveGovernanceV2.ProposalState proposalState) internal pure returns (bool) {
    if (proposalState == IAaveGovernanceV2.ProposalState.Succeeded) {
      return true;
    }
    return false;
  }

  function canProposalBeExecuted(IAaveGovernanceV2.ProposalState proposalState, IAaveGovernanceV2.ProposalWithoutVotes memory proposal) internal view returns (bool) {
    if (
      proposalState == IAaveGovernanceV2.ProposalState.Queued && 
      block.timestamp >= proposal.executionTime && 
      block.timestamp <= proposal.executionTime + proposal.executor.GRACE_PERIOD()
    ) {
      return true;
    }
    return false;
  }

  function canProposalBeCancelled(
    IAaveGovernanceV2.ProposalState proposalState, 
    IAaveGovernanceV2.ProposalWithoutVotes memory proposal,
    IAaveGovernanceV2 governanceV2
  ) internal view returns (bool) {

    IProposalValidator proposalValidator = IProposalValidator(address(proposal.executor));
    if (
      proposalState == IAaveGovernanceV2.ProposalState.Expired ||
      proposalState == IAaveGovernanceV2.ProposalState.Canceled ||
      proposalState == IAaveGovernanceV2.ProposalState.Executed
    ) {
      return false;
    }
    return proposalValidator.validateProposalCancellation(
      governanceV2,
      proposal.creator,
      block.number - 1
    );
  }
}
