// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @author BGD Labs
 * @dev
 */
interface IAaveCLRobotOperator {
  struct KeeperDetails {
    string name;
    address upkeep;
    address registry;
    address registrer;
  }
}
