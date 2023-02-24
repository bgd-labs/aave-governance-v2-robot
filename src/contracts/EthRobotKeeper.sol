// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
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
  mapping(uint256 => bool) internal disabledProposals;
  IAaveGovernanceV2 public immutable GOVERNANCE_V2;
  uint256 public constant MAX_ACTIONS = 25;
  uint256 public constant MAX_SKIP = 20;

  error NoActionCanBePerformed(uint proposalId);

  constructor(IAaveGovernanceV2 governanceV2Contract) {
    GOVERNANCE_V2 = governanceV2Contract;
  }

  /**
   * @dev run off-chain, checks if proposals should be moved to queued, executed or cancelled state
   */
  function checkUpkeep(bytes calldata) external view override returns (bool, bytes memory) {
    uint256[] memory proposalIdsToPerformAction = new uint256[](MAX_ACTIONS);
    ProposalAction[] memory actionStatesToPerformAction = new ProposalAction[](MAX_ACTIONS);

    uint256 proposalsCount = GOVERNANCE_V2.getProposalsCount();
    uint256 skipCount = 0;
    uint256 actionsCount = 0;

    // loops from the last proposalId until MAX_SKIP iterations, resets skipCount if an action could be performed
    while (proposalsCount != 0 && skipCount <= MAX_SKIP && actionsCount <= MAX_ACTIONS) {
      IAaveGovernanceV2.ProposalState proposalState = GOVERNANCE_V2.getProposalState(
        proposalsCount - 1
      );
      IAaveGovernanceV2.ProposalWithoutVotes memory proposal = GOVERNANCE_V2.getProposalById(
        proposalsCount - 1
      );

      if (!isDisabled(proposalsCount - 1)) {
        if (isProposalInFinalState(proposalState)) {
          skipCount++;
        } else {
          if (canProposalBeCancelled(proposalState, proposal)) {
            proposalIdsToPerformAction[actionsCount] = proposalsCount - 1;
            actionStatesToPerformAction[actionsCount] = ProposalAction.PerformCancel;
            actionsCount++;
          } else if (canProposalBeQueued(proposalState)) {
            proposalIdsToPerformAction[actionsCount] = proposalsCount - 1;
            actionStatesToPerformAction[actionsCount] = ProposalAction.PerformQueue;
            actionsCount++;
          } else if (canProposalBeExecuted(proposalState, proposal)) {
            proposalIdsToPerformAction[actionsCount] = proposalsCount - 1;
            actionStatesToPerformAction[actionsCount] = ProposalAction.PerformExecute;
            actionsCount++;
          }
          skipCount = 0;
        }
      }

      proposalsCount--;
    }

    if (actionsCount > 0) {
      // we do not know the length in advance, so we init arrays with MAX_ACTIONS
      // and then squeeze the array using mstore
      assembly {
        mstore(proposalIdsToPerformAction, actionsCount)
        mstore(actionStatesToPerformAction, actionsCount)
      }
      bytes memory performData = abi.encode(
        proposalIdsToPerformAction,
        actionStatesToPerformAction
      );
      return (true, performData);
    }

    return (false, '');
  }

  /**
   * @dev if proposal could be queued/executed/cancelled - executes queue/cancel/execute action on the governance contract
   * @param performData array of proposal ids, array of actions whether to queue, execute or cancel
   */
  function performUpkeep(bytes calldata performData) external override {
    (
      uint256[] memory proposalIdsToPerformAction,
      ProposalAction[] memory actionStatesToPerformAction
    ) = abi.decode(performData, (uint256[], ProposalAction[]));
    for (uint256 i = proposalIdsToPerformAction.length; i > 0; i--) {
      IAaveGovernanceV2.ProposalWithoutVotes memory proposal = GOVERNANCE_V2.getProposalById(
        proposalIdsToPerformAction[i - 1]
      );
      IAaveGovernanceV2.ProposalState proposalState = GOVERNANCE_V2.getProposalState(
        proposalIdsToPerformAction[i - 1]
      );

      // executes action on proposalIds in order from first to last
      if (
        actionStatesToPerformAction[i - 1] == ProposalAction.PerformCancel &&
        canProposalBeCancelled(proposalState, proposal)
      ) {
        GOVERNANCE_V2.cancel(proposalIdsToPerformAction[i - 1]);
      } else if (
        actionStatesToPerformAction[i - 1] == ProposalAction.PerformQueue &&
        canProposalBeQueued(proposalState)
      ) {
        GOVERNANCE_V2.queue(proposalIdsToPerformAction[i - 1]);
      } else if (
        actionStatesToPerformAction[i - 1] == ProposalAction.PerformExecute &&
        canProposalBeExecuted(proposalState, proposal)
      ) {
        GOVERNANCE_V2.execute(proposalIdsToPerformAction[i - 1]);
      } else {
        revert NoActionCanBePerformed(proposalIdsToPerformAction[i - 1]);
      }
    }
  }

  function isProposalInFinalState(
    IAaveGovernanceV2.ProposalState proposalState
  ) internal pure returns (bool) {
    if (
      proposalState == IAaveGovernanceV2.ProposalState.Executed ||
      proposalState == IAaveGovernanceV2.ProposalState.Canceled ||
      proposalState == IAaveGovernanceV2.ProposalState.Expired ||
      proposalState == IAaveGovernanceV2.ProposalState.Failed
    ) {
      return true;
    }
    return false;
  }

  function canProposalBeQueued(
    IAaveGovernanceV2.ProposalState proposalState
  ) internal pure returns (bool) {
    return proposalState == IAaveGovernanceV2.ProposalState.Succeeded;
  }

  function canProposalBeExecuted(
    IAaveGovernanceV2.ProposalState proposalState,
    IAaveGovernanceV2.ProposalWithoutVotes memory proposal
  ) internal view returns (bool) {
    if (
      proposalState == IAaveGovernanceV2.ProposalState.Queued &&
      block.timestamp >= proposal.executionTime
    ) {
      return true;
    }
    return false;
  }

  function canProposalBeCancelled(
    IAaveGovernanceV2.ProposalState proposalState,
    IAaveGovernanceV2.ProposalWithoutVotes memory proposal
  ) internal view returns (bool) {
    IProposalValidator proposalValidator = IProposalValidator(address(proposal.executor));
    if (
      proposalState == IAaveGovernanceV2.ProposalState.Expired ||
      proposalState == IAaveGovernanceV2.ProposalState.Canceled ||
      proposalState == IAaveGovernanceV2.ProposalState.Executed
    ) {
      return false;
    }
    return
      proposalValidator.validateProposalCancellation(
        GOVERNANCE_V2,
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
