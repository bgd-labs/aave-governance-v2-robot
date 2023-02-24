// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {IExecutorBase} from 'governance-crosschain-bridges/contracts/interfaces/IExecutorBase.sol';
import {IGovernanceRobotKeeper} from '../interfaces/IGovernanceRobotKeeper.sol';
import {Ownable} from 'solidity-utils/contracts/oz-common/Ownable.sol';

/**
 * @author BGD Labs
 * @dev Aave chainlink keeper-compatible contract for proposal actionsSet automation on layer 2:
 * - checks if the proposal actionsSet state could be moved to executed
 * - moves the proposal actionsSet to executed if all the conditions are met
 */
contract L2RobotKeeper is Ownable, IGovernanceRobotKeeper {
  mapping(uint256 => bool) internal disabledActionsSets;
  IExecutorBase public immutable BRIDGE_EXECUTOR;
  uint256 public constant MAX_ACTIONS = 25;
  uint256 public constant MAX_SKIP = 20;

  error NoActionCanBePerformed();

  constructor(IExecutorBase bridgeExecutorContract) {
    BRIDGE_EXECUTOR = bridgeExecutorContract;
  }

  /**
   * @dev run off-chain, checks if proposal actionsSet should be moved to executed state.
   */
  function checkUpkeep(bytes calldata) external view override returns (bool, bytes memory) {
    uint256[] memory actionsSetIdsToPerformExecute = new uint256[](MAX_ACTIONS);

    uint256 index = BRIDGE_EXECUTOR.getActionsSetCount();
    uint256 skipCount = 0;
    uint256 actionsCount = 0;

    // loops from the last actionsSetId until MAX_SKIP iterations, resets skipCount if it can be Executed
    while (index != 0 && skipCount <= MAX_SKIP && actionsCount <= MAX_ACTIONS) {
      uint256 currentId = index - 1;

      if (!isDisabled(currentId)) {
        if (canActionSetBeExecuted(currentId)) {
          skipCount = 0;
          actionsSetIdsToPerformExecute[actionsCount] = currentId;
          actionsCount++;
        } else {
          // it is in final state: executed/expired/cancelled
          skipCount++;
        }
      }

      index--;
    }

    if (actionsCount > 0) {
      // we do not know the length in advance, so we init arrays with the maxNumberOfActions
      // and then squeeze the array using mstore
      assembly {
        mstore(actionsSetIdsToPerformExecute, actionsCount)
      }
      bytes memory performData = abi.encode(actionsSetIdsToPerformExecute);
      return (true, performData);
    }

    return (false, '');
  }

  /**
   * @dev if actionsSet could be executed - performs execute action on the bridge executor contract.
   * @param performData actionsSet ids to execute.
   */
  function performUpkeep(bytes calldata performData) external override {
    uint256[] memory actionsSetIds = abi.decode(performData, (uint256[]));
    bool isActionPerformed;

    // executes action on actionSetIds in order from first to last
    for (uint i = actionsSetIds.length; i > 0; i--) {
      uint256 currentId = i - 1;

      if (canActionSetBeExecuted(actionsSetIds[currentId])) {
        try BRIDGE_EXECUTOR.execute(actionsSetIds[currentId]) {
          isActionPerformed = true;
        } catch Error(string memory reason) {
          emit ActionFailed(actionsSetIds[currentId], ProposalAction.PerformExecute, reason);
        }
      }
    }

    if (!isActionPerformed) revert NoActionCanBePerformed();
  }

  function canActionSetBeExecuted(uint256 actionsSetId) internal view returns (bool) {
    IExecutorBase.ActionsSet memory actionsSet = BRIDGE_EXECUTOR.getActionsSetById(actionsSetId);
    IExecutorBase.ActionsSetState actionsSetState = BRIDGE_EXECUTOR.getCurrentState(actionsSetId);

    if (
      actionsSetState == IExecutorBase.ActionsSetState.Queued &&
      block.timestamp >= actionsSet.executionTime
    ) {
      return true;
    }
    return false;
  }

  /// @inheritdoc IGovernanceRobotKeeper
  function isDisabled(uint256 id) public view returns (bool) {
    return disabledActionsSets[id];
  }

  /// @inheritdoc IGovernanceRobotKeeper
  function disableAutomation(uint256 id) external onlyOwner {
    disabledActionsSets[id] = true;
  }
}
