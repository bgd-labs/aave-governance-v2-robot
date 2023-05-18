// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @author BGD Labs
 * @dev
 */
interface IAaveCLRobotOperator {
  struct KeeperInfo {
    uint256 id;
    string name;
    address registry;
  }

  function toggleDisableAutomationById(address upkeep, uint256 proposalId) external;

  function isProposalDisabled(address upkeep, uint256 proposalId) external view returns (bool);
}
