// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IAaveCLRobotOperator} from '../interfaces/IAaveCLRobotOperator.sol';
import {LinkTokenInterface} from 'chainlink-brownie-contracts/interfaces/LinkTokenInterface.sol';
import {IKeeperRegistrar} from '../interfaces/IKeeperRegistrar.sol';
import {IKeeperRegistry} from '../interfaces/IKeeperRegistry.sol';

/**
 * @author BGD Labs
 * @dev
 */
contract AaveCLRobotOperator is IAaveCLRobotOperator {
  mapping(uint256 id => KeeperDetails) public keepers;
  address public immutable LINK_TOKEN;

  address public _fundsAdmin;
  address public _maintenanceAdmin;
  address public _linkWithdrawAddress;

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

  constructor(
    address linkTokenAddress,
    address linkWithdrawAddress,
    address fundsAdmin,
    address maintenanceAdmin
  ) {
    _fundsAdmin = fundsAdmin;
    _maintenanceAdmin = maintenanceAdmin;
    _linkWithdrawAddress = linkWithdrawAddress;
    LINK_TOKEN = linkTokenAddress;
  }

  function register(
    string memory name,
    address upkeepContract,
    uint32 gasLimit,
    bytes memory checkData,
    uint96 amountToFund,
    address keeperRegistry,
    address keeperRegistrer
  ) external onlyFundsAdmin returns (uint256) {
    (IKeeperRegistry.State memory state,,) = IKeeperRegistry(keeperRegistry).getState();
    uint256 oldNonce = state.nonce;

    bytes memory payload = abi.encode(
      name,
      0x0,
      upkeepContract,
      gasLimit,
      address(this),
      checkData,
      amountToFund,
      0,
      address(this)
    );
    bytes4 registerSig = IKeeperRegistrar.register.selector;
    LinkTokenInterface(LINK_TOKEN).transferAndCall(
      keeperRegistrer,
      amountToFund,
      bytes.concat(registerSig, payload)
    );

    (state,,) = IKeeperRegistry(keeperRegistry).getState();
    if (state.nonce == oldNonce + 1) {
      uint256 id = uint256(
        keccak256(
          abi.encodePacked(blockhash(block.number - 1), keeperRegistry, uint32(oldNonce))
        )
      );
      keepers[id].name = name;
      keepers[id].upkeep = upkeepContract;
      keepers[id].registry = keeperRegistry;
      keepers[id].registrer = keeperRegistrer;
      return id;
    } else {
      revert('AUTO_APPROVE_DISABLED');
    }
  }

  function cancel(uint256 id) external onlyFundsAdmin() {
    IKeeperRegistry(keepers[id].registry).cancelUpkeep(id);
  }

  function pause(uint256 id) external onlyFundsAdmin() {
    IKeeperRegistry(keepers[id].registry).pauseUpkeep(id);
  }

  function unpause(uint256 id) external onlyFundsAdmin() {
    IKeeperRegistry(keepers[id].registry).unpauseUpkeep(id);
  }

  function setGasLimit(uint256 id, uint32 gasLimit) external onlyMaintenanceAdmin() {
    IKeeperRegistry(keepers[id].registry).setUpkeepGasLimit(id, gasLimit);
  }

  function withdrawLink(uint256 id) external {
    IKeeperRegistry(keepers[id].registry).withdrawFunds(
      id,
      _linkWithdrawAddress
    );
  }

  function setWithdrawAddress(address newWithdrawAddress) external onlyFundsAdmin {
    _linkWithdrawAddress = newWithdrawAddress;
  }

  function getFundsAdmin() external view returns (address) {
    return _fundsAdmin;
  }

  function getMaintenanceAdmin() external view returns (address) {
    return _maintenanceAdmin;
  }

  function getWithdrawAddress() external view returns (address) {
    return _linkWithdrawAddress;
  }
}
