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

  error NoActionCanBePerformed();

  constructor(IAaveGovernanceV2 governanceV2Contract) {
    GOVERNANCE_V2 = governanceV2Contract;
  }

  /**
   * @dev run off-chain, checks if proposals should be moved to queued, executed or cancelled state
   */
  function checkUpkeep(bytes calldata) external view override returns (bool, bytes memory) {
    ActionWithId[] memory actionsWithIds = new ActionWithId[](MAX_ACTIONS);

    uint256 index = GOVERNANCE_V2.getProposalsCount();
    uint256 skipCount = 0;
    uint256 actionsCount = 0;

    // loops from the last proposalId until MAX_SKIP iterations, resets skipCount if an action could be performed
    while (index != 0 && skipCount <= MAX_SKIP && actionsCount < MAX_ACTIONS) {
      uint256 proposalId = index - 1;

      IAaveGovernanceV2.ProposalState proposalState = GOVERNANCE_V2.getProposalState(proposalId);
      IAaveGovernanceV2.ProposalWithoutVotes memory proposal = GOVERNANCE_V2.getProposalById(
        proposalId
      );

      if (!isDisabled(proposalId)) {
        if (_isProposalInFinalState(proposalState)) {
          skipCount++;
        } else {
          if (_canProposalBeCancelled(proposalState, proposal)) {
            actionsWithIds[actionsCount].id = proposalId;
            actionsWithIds[actionsCount].action = ProposalAction.PerformCancel;
            actionsCount++;
          } else if (_canProposalBeQueued(proposalState)) {
            actionsWithIds[actionsCount].id = proposalId;
            actionsWithIds[actionsCount].action = ProposalAction.PerformQueue;
            actionsCount++;
          } else if (_canProposalBeExecuted(proposalState, proposal)) {
            actionsWithIds[actionsCount].id = proposalId;
            actionsWithIds[actionsCount].action = ProposalAction.PerformExecute;
            actionsCount++;
          }
          skipCount = 0;
        }
      }

      index--;
    }

    if (actionsCount > 0) {
      // we do not know the length in advance, so we init arrays with MAX_ACTIONS
      // and then squeeze the array using mstore
      assembly {
        mstore(actionsWithIds, actionsCount)
      }
      bytes memory performData = abi.encode(actionsWithIds);
      return (true, performData);
    }

    return (false, '');
  }

  /**
   * @dev if proposal could be queued/executed/cancelled - executes queue/cancel/execute action on the governance contract
   * @param performData array of proposal ids, array of actions whether to queue, execute or cancel
   */
  function performUpkeep(bytes calldata performData) external override {
    ActionWithId[] memory actionsWithIds = abi.decode(performData, (ActionWithId[]));
    bool isActionPerformed;

    // executes action on proposalIds in order from first to last
    for (uint256 i = actionsWithIds.length; i > 0; i--) {
      uint256 proposalId = actionsWithIds[i - 1].id;
      ProposalAction action = actionsWithIds[i - 1].action;

      IAaveGovernanceV2.ProposalWithoutVotes memory proposal = GOVERNANCE_V2.getProposalById(
        proposalId
      );
      IAaveGovernanceV2.ProposalState proposalState = GOVERNANCE_V2.getProposalState(
        proposalId
      );

      if (
        action == ProposalAction.PerformCancel &&
        _canProposalBeCancelled(proposalState, proposal)
      ) {
        try GOVERNANCE_V2.cancel(proposalId) {
          isActionPerformed = true;
          emit ActionSucceeded(proposalId, action);
        } catch Error(string memory reason) {
          emit ActionFailed(proposalId, action, reason);
        }
      } else if (
        action == ProposalAction.PerformQueue &&
        _canProposalBeQueued(proposalState)
      ) {
        try GOVERNANCE_V2.queue(proposalId) {
          isActionPerformed = true;
          emit ActionSucceeded(proposalId, action);
        } catch Error(string memory reason) {
          emit ActionFailed(proposalId, action, reason);
        }
      } else if (
        action == ProposalAction.PerformExecute &&
        _canProposalBeExecuted(proposalState, proposal)
      ) {
        try GOVERNANCE_V2.execute(proposalId) {
          isActionPerformed = true;
          emit ActionSucceeded(proposalId, action);
        } catch Error(string memory reason) {
          emit ActionFailed(proposalId, action, reason);
        }
      }
    }

    if (!isActionPerformed) revert NoActionCanBePerformed();
  }

  /// @inheritdoc IGovernanceRobotKeeper
  function isDisabled(uint256 id) public view returns (bool) {
    return disabledProposals[id];
  }

  /// @inheritdoc IGovernanceRobotKeeper
  function disableAutomation(uint256 id) external onlyOwner {
    disabledProposals[id] = true;
  }

  function _isProposalInFinalState(
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

  function _canProposalBeQueued(
    IAaveGovernanceV2.ProposalState proposalState
  ) internal pure returns (bool) {
    return proposalState == IAaveGovernanceV2.ProposalState.Succeeded;
  }

  function _canProposalBeExecuted(
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

  function _canProposalBeCancelled(
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
}
