// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {KeeperCompatibleInterface} from 'chainlink-brownie-contracts/KeeperCompatible.sol';
import {IAaveGovernanceV2, IExecutorWithTimelock} from 'aave-address-book/AaveGovernanceV2.sol';
import {IProposalValidator} from '../interfaces/IProposalValidator.sol';
import {IGovernanceRobotKeeper} from '../interfaces/IGovernanceRobotKeeper.sol';
import {Ownable} from 'solidity-utils/contracts/oz-common/Ownable.sol';

/**
 * @author BGD Labs
 * @dev Aave chainlink keeper-compatible contract for proposal automation:
 * - checks if the proposal state could be moved to queued, executed or cancelled
 * - moves the proposal to queued/executed/cancelled if all the conditions are met
 */
contract EthRobotKeeper is Ownable, IGovernanceRobotKeeper {

  mapping (uint256 => bool) public disabledProposals;

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

    uint256 maxNumberOfActions = 25;
    uint256 actionsCount;
    uint256[] memory proposalIdsToPerformAction = new uint256[](maxNumberOfActions);
    ProposalAction[] memory actionStatesToPerformAction = new ProposalAction[](maxNumberOfActions);

    uint256 proposalsCount = governanceV2.getProposalsCount();
    uint256 proposalsStartLimit = 0;

    // iterate from the last proposal till we find an executed proposal
    for (uint256 proposalId = proposalsCount - 1; proposalId >= 0; proposalId--) {
      if (governanceV2.getProposalState(proposalId) == IAaveGovernanceV2.ProposalState.Executed) {
        proposalId < 20 ? proposalsStartLimit = 0 : proposalsStartLimit = proposalId - 20;
        break;
      }
    }

    // iterate from an executed proposal minus 20 to be sure, also checks if actionsCount is less than the maxNumberOfActions
    for (uint256 proposalId = proposalsStartLimit; proposalId < proposalsCount && actionsCount < maxNumberOfActions; proposalId++) {

      IAaveGovernanceV2.ProposalWithoutVotes memory proposal = governanceV2.getProposalById(proposalId);
      IAaveGovernanceV2.ProposalState proposalState = governanceV2.getProposalState(proposalId);

      if (isDisabled(proposalId)) {
        continue;
      }

      if (canProposalBeCancelled(proposalState, proposal, governanceV2)) {
        proposalIdsToPerformAction[actionsCount] = proposalId;
        actionStatesToPerformAction[actionsCount] = ProposalAction.PerformCancel;
        actionsCount++;
      } else if (canProposalBeQueued(proposalState)) {
        proposalIdsToPerformAction[actionsCount] = proposalId;
        actionStatesToPerformAction[actionsCount] = ProposalAction.PerformQueue;
        actionsCount++;
      } else if (canProposalBeExecuted(proposalState, proposal)) {
        proposalIdsToPerformAction[actionsCount] = proposalId;
        actionStatesToPerformAction[actionsCount] = ProposalAction.PerformExecute;
        actionsCount++;
      }
    }

    if (actionsCount > 0) {
      // we do not know the length in advance, so we init arrays with the maxNumberOfActions
      // and then squeeze the array using mstore
      assembly {
        mstore(proposalIdsToPerformAction, actionsCount)
        mstore(actionStatesToPerformAction, actionsCount)
      }
      bytes memory performData = abi.encode(governanceV2, proposalIdsToPerformAction, actionStatesToPerformAction);
      return (true, performData);
    }
      
    return (false, checkData);
  }

  /**
   * @dev if proposal could be queued/executed/cancelled - executes queue/cancel/execute action on the governance contract
   * @param performData governance contract, array of proposal ids, array of actions whether to queue, execute or cancel
   */
  function performUpkeep(bytes calldata performData) external override {
    (IAaveGovernanceV2 governanceV2, uint256[] memory proposalIdsToPerformAction, ProposalAction[] memory actionStatesToPerformAction) = abi.decode(performData, (IAaveGovernanceV2, uint256[], ProposalAction[]));

    for (uint256 i=0; i<proposalIdsToPerformAction.length; i++) {

      IAaveGovernanceV2.ProposalWithoutVotes memory proposal = governanceV2.getProposalById(proposalIdsToPerformAction[i]);
      IAaveGovernanceV2.ProposalState proposalState = governanceV2.getProposalState(proposalIdsToPerformAction[i]);

      if (actionStatesToPerformAction[i] == ProposalAction.PerformCancel) {
        require(canProposalBeCancelled(proposalState, proposal, governanceV2), 'INVALID_STATE_FOR_CANCEL');
        governanceV2.cancel(proposalIdsToPerformAction[i]);
      } else if (actionStatesToPerformAction[i] == ProposalAction.PerformQueue) {
        require(canProposalBeQueued(proposalState), 'INVALID_STATE_FOR_QUEUE');
        governanceV2.queue(proposalIdsToPerformAction[i]);
      } else if (actionStatesToPerformAction[i] == ProposalAction.PerformExecute) {
        require(canProposalBeExecuted(proposalState, proposal), 'INVALID_STATE_FOR_EXECUTE');
        governanceV2.execute(proposalIdsToPerformAction[i]);
      }
    }
  }

  function canProposalBeQueued(IAaveGovernanceV2.ProposalState proposalState) internal pure returns (bool) {
    return proposalState == IAaveGovernanceV2.ProposalState.Succeeded;
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

  /// @inheritdoc IGovernanceRobotKeeper
  function isDisabled(uint256 id) public view returns (bool) {
    return disabledProposals[id];
  }

  /// @inheritdoc IGovernanceRobotKeeper
  function disableAutomation(uint256 id) external onlyOwner {
    disabledProposals[id] = true;
  }
}
