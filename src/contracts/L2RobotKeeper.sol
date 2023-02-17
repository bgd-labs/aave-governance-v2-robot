// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {KeeperCompatibleInterface} from 'chainlink-brownie-contracts/KeeperCompatible.sol';
import {IAaveGovernanceV2, IExecutorWithTimelock} from 'aave-address-book/AaveGovernanceV2.sol';
import {IExecutorBase} from 'governance-crosschain-bridges/contracts/interfaces/IExecutorBase.sol';
import {IGovernanceRobotKeeper} from '../interfaces/IGovernanceRobotKeeper.sol';

/**
 * @author BGD Labs
 * @dev Aave chainlink keeper-compatible contract for proposal actionsSet automation on layer 2:
 * - checks if the proposal actionsSet state could be moved to executed
 * - moves the proposal actionsSet to executed if all the conditions are met
 */
contract L2RobotKeeper is IGovernanceRobotKeeper {

  /**
   * @dev run off-chain, checks if proposal actionsSet should be moved to executed state
   * @param checkData address of the bridge executor contract
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

    uint256 actionsSetCount = bridgeExecutor.getActionsSetCount();
    uint256 actionsSetStartLimit = 0;

    // iterate from the last actionsSet till we find an executed actionsSet
    for (uint256 actionsSetId = actionsSetCount - 1; actionsSetId >= 0; actionsSetId--) {
      if (bridgeExecutor.getCurrentState(actionsSetId) == IExecutorBase.ActionsSetState.Executed) {
        actionsSetId < 20 ? actionsSetStartLimit = 0 : actionsSetStartLimit = actionsSetId - 20;
        break;
      }
    }

    // iterate from an executed actionsSet minus 20 to be sure
    for (uint256 actionsSetId = actionsSetStartLimit; actionsSetId < actionsSetCount; actionsSetId++) {
      if (canActionSetBeExecuted(actionsSetId, executorAddress)) {
        bytes memory performData = abi.encode(executorAddress, actionsSetId);
        return (true, performData);
      }
    }

    return (false, checkData);
  }

  /**
   * @dev if actionsSet could be executed - executes execute action on the bridge executor contract
   * @param performData address of the bridge executor contract, actionsSet id
   */
  function performUpkeep(bytes calldata performData) external override {
    (address executorAddress, uint256 actionsSetId) = abi.decode(performData, (address, uint256));
    IExecutorBase bridgeExecutor = IExecutorBase(
      executorAddress
    );

    require(canActionSetBeExecuted(actionsSetId, executorAddress), 'INVALID_STATE_FOR_EXECUTE');
    bridgeExecutor.execute(actionsSetId);
  }

  function canActionSetBeExecuted(uint256 actionsSetId, address executorAddress) internal view returns (bool) {
    IExecutorBase bridgeExecutor = IExecutorBase(
      executorAddress
    );
    IExecutorBase.ActionsSet memory actionsSet = bridgeExecutor.getActionsSetById(actionsSetId);
    IExecutorBase.ActionsSetState actionsSetState = bridgeExecutor.getCurrentState(actionsSetId);

    if (
      actionsSetState == IExecutorBase.ActionsSetState.Queued &&
      block.timestamp >= actionsSet.executionTime &&
      block.timestamp <= actionsSet.executionTime + bridgeExecutor.getGracePeriod()
    ) {
      return true;
    }
    return false;
  }
}