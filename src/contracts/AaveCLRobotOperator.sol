// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IAaveCLRobotOperator} from '../interfaces/IAaveCLRobotOperator.sol';
import {LinkTokenInterface} from 'chainlink-brownie-contracts/interfaces/LinkTokenInterface.sol';
import {KeeperRegistrarInterface as IKeeperRegistrar} from '../interfaces/KeeperRegistrarInterface.sol';
import {AutomationRegistryInterface as IKeeperRegistry} from 'chainlink-brownie-contracts/interfaces/AutomationRegistryInterface2_0.sol';

/**
 * @author BGD Labs
 * @dev
 */
contract AaveCLRobotOperator is IAaveCLRobotOperator {
  mapping(uint256 id => KeeperDetails) public keepers;
  address public immutable LINK_TOKEN;
  address public immutable LINK_WITHDRAW_ADDRESS;

  address public _fundsAdmin;
  address public _maintenanceAdmin;

  /**
   * @dev Only funds admin can call functions marked by this modifier.
   */
  modifier onlyFundsAdmin() {
    require(msg.sender == _fundsAdmin, 'CALLER_NOT_FUNDS_ADMIN');
    _;
  }

  /**
   * @dev Only maintenance admin can call functions marked by this modifier.
   */
  modifier onlyMaintenanceAdmin() {
    require(msg.sender == _maintenanceAdmin, 'CALLER_NOT_MAINTENANCE_ADMIN');
    _;
  }

  /**
   * @dev
   */
  modifier isRegisteredKeeper(uint256 id) {
    require(
      keepers[id].upkeep != address(0) &&
      keepers[id].registrer != address(0) &&
      keepers[id].registry != address(0),
      'INVALID_KEEPER'
    );
    _;
  }

  constructor(
    address linkTokenAddress,
    address linkWithdrawAddress,
    address fundsAdmin,
    address maintenanceAdmin
  ) {
    _fundsAdmin = fundsAdmin;
    _maintenanceAdmin = maintenanceAdmin;
    LINK_TOKEN = linkTokenAddress;
    LINK_WITHDRAW_ADDRESS = linkWithdrawAddress;
  }

  function register(
    string memory name,
    address upkeepContract,
    uint96 amountToFund,
    uint32 gasLimit,
    bytes memory checkData,
    address keeperRegistry,
    address keeperRegistrer
  ) external onlyFundsAdmin {
    LinkTokenInterface(LINK_TOKEN).approve(
      keeperRegistrer,
      amountToFund
    );
    uint256 id = IKeeperRegistrar(keeperRegistrer).registerUpkeep(
      IKeeperRegistrar.RegistrationParams({
        name: name,
        encryptedEmail: '',
        upkeepContract: upkeepContract,
        gasLimit: gasLimit,
        adminAddress: address(this),
        checkData: checkData,
        offchainConfig: '',
        amount: amountToFund
      })
    );
    keepers[id].name = name;
    keepers[id].upkeep = upkeepContract;
    keepers[id].registry = keeperRegistry;
    keepers[id].registrer = keeperRegistrer;
  }

  function cancel(uint256 id) external isRegisteredKeeper(id) {
    IKeeperRegistry(keepers[id].registry).cancelUpkeep(id);
  }

  function pause(uint256 id) external isRegisteredKeeper(id) {
    IKeeperRegistry(keepers[id].registry).pauseUpkeep(id);
  }

  function unpause(uint256 id) external isRegisteredKeeper(id) {
    IKeeperRegistry(keepers[id].registry).unpauseUpkeep(id);
  }

  function withdrawLink(uint id) external {
    // TODO
  }

  function getFundsAdmin() external view returns (address) {
    return _fundsAdmin;
  }

  function getMaintenanceAdmin() external view returns (address) {
    return _maintenanceAdmin;
  }
}
