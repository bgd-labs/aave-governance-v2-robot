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
  mapping(uint256 => bool) public disabledProposals;
  uint256 constant MAX_ACTIONS = 25;
  uint256 constant MAX_SKIP = 20;

  error NoActionPerformed(uint proposalId);

  /**
   * @dev run off-chain, checks if proposals should be moved to queued, executed or cancelled state
   * @param checkData address of the governance contract
   */
  function checkUpkeep(
    bytes calldata checkData
  ) external view override returns (bool, bytes memory) {
    address governanceAddress = abi.decode(checkData, (address));
    IAaveGovernanceV2 governanceV2 = IAaveGovernanceV2(governanceAddress);

    uint256[] memory proposalIdsToPerformAction = new uint256[](MAX_ACTIONS);
    ProposalAction[] memory actionStatesToPerformAction = new ProposalAction[](MAX_ACTIONS);

    uint256 index = governanceV2.getProposalsCount();
    uint256 skipCount = 0;
    uint256 actionsCount = 0;

    // loops from the last proposalId until MAX_SKIP iterations, resets skipCount if an action could be performed
    while (index != 0 && skipCount <= MAX_SKIP && actionsCount <= MAX_ACTIONS) {
      IAaveGovernanceV2.ProposalState proposalState = governanceV2.getProposalState(index - 1);
      IAaveGovernanceV2.ProposalWithoutVotes memory proposal = governanceV2.getProposalById(
        index - 1
      );

      if (isDisabled(index - 1)) {
        skipCount++;
      } else if (canProposalBeCancelled(proposalState, proposal, governanceV2)) {
        proposalIdsToPerformAction[actionsCount] = index - 1;
        actionStatesToPerformAction[actionsCount] = ProposalAction.PerformCancel;
        actionsCount++;
        skipCount = 0;
      } else if (canProposalBeQueued(proposalState)) {
        proposalIdsToPerformAction[actionsCount] = index - 1;
        actionStatesToPerformAction[actionsCount] = ProposalAction.PerformQueue;
        actionsCount++;
        skipCount = 0;
      } else if (canProposalBeExecuted(proposalState, proposal)) {
        proposalIdsToPerformAction[actionsCount] = index - 1;
        actionStatesToPerformAction[actionsCount] = ProposalAction.PerformExecute;
        actionsCount++;
        skipCount = 0;
      } else if (
        proposalState != IAaveGovernanceV2.ProposalState.Active ||
        proposalState != IAaveGovernanceV2.ProposalState.Pending
      ) {
        // in final state executed/cancelled/expired/failed
        skipCount++;
      }

      index--;
    }

    if (actionsCount > 0) {
      // we do not know the length in advance, so we init arrays with MAX_ACTIONS
      // and then squeeze the array using mstore
      assembly {
        mstore(proposalIdsToPerformAction, actionsCount)
        mstore(actionStatesToPerformAction, actionsCount)
      }
      bytes memory performData = abi.encode(
        governanceV2,
        proposalIdsToPerformAction,
        actionStatesToPerformAction
      );
      return (true, performData);
    }

    return (false, checkData);
  }

  /**
   * @dev if proposal could be queued/executed/cancelled - executes queue/cancel/execute action on the governance contract
   * @param performData governance contract, array of proposal ids, array of actions whether to queue, execute or cancel
   */
  function performUpkeep(bytes calldata performData) external override {
    (
      IAaveGovernanceV2 governanceV2,
      uint256[] memory proposalIdsToPerformAction,
      ProposalAction[] memory actionStatesToPerformAction
    ) = abi.decode(performData, (IAaveGovernanceV2, uint256[], ProposalAction[]));

    for (uint256 i = proposalIdsToPerformAction.length; i > 0; i--) {
      IAaveGovernanceV2.ProposalWithoutVotes memory proposal = governanceV2.getProposalById(
        proposalIdsToPerformAction[i - 1]
      );
      IAaveGovernanceV2.ProposalState proposalState = governanceV2.getProposalState(
        proposalIdsToPerformAction[i - 1]
      );

      // executes action on proposalIds in order from first to last
      if (
        actionStatesToPerformAction[i - 1] == ProposalAction.PerformCancel &&
        canProposalBeCancelled(proposalState, proposal, governanceV2)
      ) {
        governanceV2.cancel(proposalIdsToPerformAction[i - 1]);
      } else if (
        actionStatesToPerformAction[i - 1] == ProposalAction.PerformQueue &&
        canProposalBeQueued(proposalState)
      ) {
        governanceV2.queue(proposalIdsToPerformAction[i - 1]);
      } else if (
        actionStatesToPerformAction[i - 1] == ProposalAction.PerformExecute &&
        canProposalBeExecuted(proposalState, proposal)
      ) {
        governanceV2.execute(proposalIdsToPerformAction[i - 1]);
      } else {
        revert NoActionPerformed(proposalIdsToPerformAction[i - 1]);
      }
    }
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
    return
      proposalValidator.validateProposalCancellation(
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
