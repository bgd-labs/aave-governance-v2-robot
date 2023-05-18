// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AutomationCompatibleInterface} from 'chainlink-brownie-contracts/interfaces/AutomationCompatibleInterface.sol';

/**
 * @title IL2RobotKeeper
 * @author BGD Labs
 * @notice Defines the interface for the contract to automate actions on aave governance v2 bridge executors.
 **/
interface IL2RobotKeeper is AutomationCompatibleInterface {
  /**
   * @dev Emitted when performUpkeep is called and no actions are executed.
   * @param id actionsSetId of failed action.
   * @param action action performed on the actionsSet which faled.
   * @param reason reason of the failed action.
   */
  event ActionFailed(uint256 indexed id, ProposalAction indexed action, string reason);

  /**
   * @dev Emitted when performUpkeep is called and actions are executed.
   * @param id actionsSetId id of successful action.
   * @param action successful action performed on the actionsSetId.
   */
  event ActionSucceeded(uint256 indexed id, ProposalAction indexed action);

  /**
   * @notice Actions that can be performed by the robot on the bridge executor.
   * @param PerformExecute: performs execute action on the bridge executor.
   **/
  enum ProposalAction {
    PerformExecute
  }

  /**
   * @notice holds action to be performed for a given actionsSetId.
   * @param id actionsSetId for which action needs to be performed.
   * @param action action to be perfomed for the actionsSetId.
   */
  struct ActionWithId {
    uint256 id;
    ProposalAction action;
  }

  /**
   * @notice method to get the address of the aave bridge executor contract.
   * @return bridge executor contract address.
   */
  function BRIDGE_EXECUTOR() external returns (address);

  /**
   * @notice method to get the maximum number of actions that can be performed by the keeper in one performUpkeep.
   * @return max number of actions.
   */
  function MAX_ACTIONS() external returns (uint256);

  /**
   * @notice method to get maximum number of actionsSet to check before the latest actionsSet, if an action could be performed upon.
   * @return max number of skips.
   */
  function MAX_SKIP() external returns (uint256);

  /**
   * @notice method to get the address of robot operator which performs the admin actions on the keeper.
   * @return robot operator contract address.
   */
  function ROBOT_OPERATOR() external returns (address);
}
