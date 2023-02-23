// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {KeeperCompatibleInterface} from 'chainlink-brownie-contracts/KeeperCompatible.sol';
import {IAaveGovernanceV2, IExecutorWithTimelock} from 'aave-address-book/AaveGovernanceV2.sol';
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

  mapping (uint256 => bool) public disabledActionsSets;
  uint256 constant MAX_ACTIONS = 25;
  error NoActionPerformed(uint actionsSetId);

  /**
   * @dev run off-chain, checks if proposal actionsSet should be moved to executed state.
   * @param checkData address of the bridge executor contract.
   */
  function checkUpkeep(bytes calldata checkData)
    external
    view
    override
    returns (bool, bytes memory)
  {
    address executorAddress = abi.decode(checkData, (address));
    IExecutorBase bridgeExecutor = IExecutorBase(
      executorAddress
    );

    uint256 actionsCount;
    uint256[] memory actionsSetIdsToPerformExecute = new uint256[](MAX_ACTIONS);

    uint256 actionsSetCount = bridgeExecutor.getActionsSetCount();
    uint256 actionsSetStartLimit = 0;

    // iterate from the last actionsSet till we find an executed actionsSet
    for (uint256 actionsSetId = actionsSetCount - 1; actionsSetId >= 0; actionsSetId--) {
      if (isDisabled(actionsSetId)) {
        continue;
      } 
 
      if (bridgeExecutor.getCurrentState(actionsSetId) == IExecutorBase.ActionsSetState.Executed) {
        actionsSetStartLimit = actionsSetId < 20 ? 0 : actionsSetId - 20;
        break;
      }
    }

    // iterate from an executed actionsSet minus 20 to be sure, also checks if actionsCount is less than the maxNumberOfActions
    for (uint256 actionsSetId = actionsSetStartLimit; actionsSetId < actionsSetCount && actionsCount < MAX_ACTIONS; actionsSetId++) {
      if (canActionSetBeExecuted(actionsSetId, bridgeExecutor)) {
        actionsSetIdsToPerformExecute[actionsCount] = actionsSetId;
        actionsCount++;
      }
    }

    if (actionsCount > 0) {
      // we do not know the length in advance, so we init arrays with the maxNumberOfActions
      // and then squeeze the array using mstore
      assembly {
        mstore(actionsSetIdsToPerformExecute, actionsCount)
      }
      bytes memory performData = abi.encode(bridgeExecutor, actionsSetIdsToPerformExecute);
      return (true, performData);
    }

    return (false, checkData);
  }

  /**
   * @dev if actionsSet could be executed - performs execute action on the bridge executor contract.
   * @param performData bridge executor, actionsSet ids to execute.
   */
  function performUpkeep(bytes calldata performData) external override {
    (IExecutorBase bridgeExecutor, uint256[] memory actionsSetIds) = abi.decode(performData, (IExecutorBase, uint256[]));

    for (uint i=0; i<actionsSetIds.length; i++) {
      if (canActionSetBeExecuted(actionsSetIds[i], bridgeExecutor)) {
        bridgeExecutor.execute(actionsSetIds[i]);
      } else {
        revert NoActionPerformed(actionsSetIds[i]);
      }
    }
  }

  function canActionSetBeExecuted(uint256 actionsSetId, IExecutorBase bridgeExecutor) internal view returns (bool) {
    IExecutorBase.ActionsSet memory actionsSet = bridgeExecutor.getActionsSetById(actionsSetId);
    IExecutorBase.ActionsSetState actionsSetState = bridgeExecutor.getCurrentState(actionsSetId);

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
