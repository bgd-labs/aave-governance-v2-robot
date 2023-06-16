// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IAaveCLRobotOperator
 * @author BGD Labs
 * @notice Defines the interface for the robot operator contract to perform admin actions on the automation keepers.
 **/
interface IAaveCLRobotOperator {
  /**
   * @notice holds the keeper info registered via the operator.
   * @param id chainlink id of the registered keeper.
   * @param name name of the registered keeper.
   */
  struct KeeperInfo {
    uint256 id;
    string name;
  }

  /**
   * @notice method called by funds admin to register the automation robot keeper.
   * @param name - name of keeper.
   * @param upkeepContract - upkeepContract of the keeper.
   * @param gasLimit - max gasLimit which the chainlink automation node can execute for the automation.
   * @param amountToFund - amount of link to fund the keeper with.
   * @return chainlink id for the registered keeper.
   **/
  function register(
    string memory name,
    address upkeepContract,
    uint32 gasLimit,
    uint96 amountToFund
  ) external returns (uint256);

  /**
   * @notice method called to refill the keeper.
   * @param upkeep - address of the upkeep contract.
   * @param amount - amount of LINK to refill the keeper with.
   **/
  function refillKeeper(address upkeep, uint96 amount) external;

  /**
   * @notice method called by funds admin to cancel the automation robot keeper.
   * @param upkeep address of the upkeep robot keeper contract to cancel.
   **/
  function cancel(address upkeep) external;

  /**
   * @notice method called by funds admin to withdraw link of automation robot keeper to the withdraw address.
   *         this method should only be called after the automation robot keeper is cancelled.
   * @param upkeep address of the upkeep robot keeper contract to withdraw funds of.
   **/
  function withdrawLink(address upkeep) external;

  /**
   * @notice method called by funds admin/maintenance admin to set the max gasLimit of upkeep robot keeper.
   * @param upkeep address of the upkeep robot keeper contract to set the gasLimit.
   * @param gasLimit max gasLimit which the chainlink automation node can execute.
   **/
  function setGasLimit(address upkeep, uint32 gasLimit) external;

  /**
   * @notice method called by funds admin to set the withdraw address when withdrawing excess link from the automation robot keeeper.
   * @param withdrawAddress withdraw address to withdaw link to.
   **/
  function setWithdrawAddress(address withdrawAddress) external;

  /**
   * @notice method called by funds admin to set the new funds admin.
   * @param fundsAdmin address of new funds admin to set.
   **/
  function setFundsAdmin(address fundsAdmin) external;

  /**
   * @notice method called by either funds admin or maintenance admin to set the new maintenance admin.
   * @param maintenanceAdmin address of new maintenance admin to set.
   **/
  function setMaintenanceAdmin(address maintenanceAdmin) external;

  /**
   * @notice method called by funds admin/maintenance admin to disable/enabled automation on a specific proposalId for the given automation robot keeper.
   * @param upkeep address of automation robot keeper.
   * @param proposalId proposalId for which we need to disable/enable automation.
   **/
  function toggleDisableAutomationById(address upkeep, uint256 proposalId) external;

  /**
   * @notice method to check if automation for the proposalId for the given robot keeper is disabled/enabled.
   * @param upkeep address of automation robot keeper.
   * @param proposalId proposalId to check if automation is disabled or not.
   * @return bool if automation for proposalId is disabled or not.
   **/
  function isProposalDisabled(address upkeep, uint256 proposalId) external view returns (bool);

  /**
   * @notice method to get the funds admin for the robot operator contract.
   * @return address of the funds admin.
   **/
  function getFundsAdmin() external view returns (address);

  /**
   * @notice method to get the maintenance admin for the robot operator contract.
   * @return address of the maintenance admin.
   **/
  function getMaintenanceAdmin() external view returns (address);

  /**
   * @notice method to get the withdraw address for the robot operator contract.
   * @return withdraw address to send excess link to.
   **/
  function getWithdrawAddress() external view returns (address);

  /**
   * @notice method to get the keeper information registered via the operator.
   * @return Struct containing the following information about the keeper:
   *         - uint256 chainlink id of the registered keeper.
   *         - string name of the registered keeper.
   *         - address chainlink registry of the registered keeper.
   **/
  function getKeeperInfo(address upkeep) external view returns (KeeperInfo memory);

  /**
   * @notice method to get the address of ERC-677 link token.
   * @return link token address.
   */
  function LINK_TOKEN() external returns (address);

  /**
   * @notice method to get the address of chainlink keeper registry contract.
   * @return keeper registry address.
   */
  function KEEPER_REGISTRY() external returns (address);

  /**
   * @notice method to get the address of chainlink keeper registrar contract.
   * @return keeper registrar address.
   */
  function KEEPER_REGISTRAR() external returns (address);
}
