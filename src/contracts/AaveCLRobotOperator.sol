// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IAaveCLRobotOperator} from '../interfaces/IAaveCLRobotOperator.sol';
import {LinkTokenInterface} from 'chainlink-brownie-contracts/interfaces/LinkTokenInterface.sol';
import {IKeeperRegistrar} from '../interfaces/IKeeperRegistrar.sol';
import {IKeeperRegistry} from '../interfaces/IKeeperRegistry.sol';

/**
 * @title AaveCLRobotOperator
 * @author BGD Labs
 * @dev Operator contract to perform admin actions on the automation keepers.
 *      The contract can register keepers, cancel it, withdraw excess link,
 *      configure the registered keepers and disable automation on a certain proposal.
 */
contract AaveCLRobotOperator is IAaveCLRobotOperator {
  /// @inheritdoc IAaveCLRobotOperator
  address public immutable LINK_TOKEN;

  address internal _fundsAdmin;
  address internal _maintenanceAdmin;
  address internal _linkWithdrawAddress;

  mapping(address upkeep => KeeperInfo) internal _keepers;

  mapping(address upkeep => mapping(uint256 proposalId => bool isDisabled))
    internal _disabledProposals;

  /**
   * @dev Only funds admin can call functions marked by this modifier.
   */
  modifier onlyFundsAdmin() {
    require(msg.sender == _fundsAdmin, 'CALLER_NOT_FUNDS_ADMIN');
    _;
  }

  /**
   * @dev Only maintenance admin or funds admin can call functions marked by this modifier.
   */
  modifier onlyMaintenanceOrFundsAdmin() {
    require(
      msg.sender == _maintenanceAdmin || msg.sender == _fundsAdmin,
      'CALLER_NOT_MAINTENANCE_OR_FUNDS_ADMIN'
    );
    _;
  }

  /**
   * @param linkTokenAddress address of the ERC-677 link token contract.
   * @param linkWithdrawAddress withdrawal address to send the exccess link after cancelling the keeper.
   * @param fundsAdmin address of funds admin.
   * @param maintenanceAdmin address of the maintenance admin.
   */
  constructor(
    address linkTokenAddress,
    address linkWithdrawAddress,
    address fundsAdmin,
    address maintenanceAdmin
  ) {
    LINK_TOKEN = linkTokenAddress;
    _linkWithdrawAddress = linkWithdrawAddress;
    _fundsAdmin = fundsAdmin;
    _maintenanceAdmin = maintenanceAdmin;
  }

  /// @inheritdoc IAaveCLRobotOperator
  function register(
    string memory name,
    address upkeepContract,
    uint32 gasLimit,
    bytes memory checkData,
    uint96 amountToFund,
    address keeperRegistry,
    address keeperRegistrar
  ) external onlyFundsAdmin returns (uint256) {
    (IKeeperRegistry.State memory state, , ) = IKeeperRegistry(keeperRegistry).getState();
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
      keeperRegistrar,
      amountToFund,
      bytes.concat(registerSig, payload)
    );

    (state, , ) = IKeeperRegistry(keeperRegistry).getState();
    if (state.nonce == oldNonce + 1) {
      uint256 id = uint256(
        keccak256(abi.encodePacked(blockhash(block.number - 1), keeperRegistry, uint32(oldNonce)))
      );
      _keepers[upkeepContract].id = id;
      _keepers[upkeepContract].name = name;
      _keepers[upkeepContract].registry = keeperRegistry;
      return id;
    } else {
      revert('AUTO_APPROVE_DISABLED');
    }
  }

  /// @inheritdoc IAaveCLRobotOperator
  function cancel(address upkeep) external onlyFundsAdmin {
    IKeeperRegistry(_keepers[upkeep].registry).cancelUpkeep(_keepers[upkeep].id);
  }

  /// @inheritdoc IAaveCLRobotOperator
  function withdrawLink(address upkeep) external {
    IKeeperRegistry(_keepers[upkeep].registry).withdrawFunds(
      _keepers[upkeep].id,
      _linkWithdrawAddress
    );
  }

  /// @inheritdoc IAaveCLRobotOperator
  function setGasLimit(address upkeep, uint32 gasLimit) external onlyMaintenanceOrFundsAdmin {
    IKeeperRegistry(_keepers[upkeep].registry).setUpkeepGasLimit(_keepers[upkeep].id, gasLimit);
  }

  /// @inheritdoc IAaveCLRobotOperator
  function setWithdrawAddress(address newWithdrawAddress) external onlyFundsAdmin {
    _linkWithdrawAddress = newWithdrawAddress;
  }

  /// @inheritdoc IAaveCLRobotOperator
  function toggleDisableAutomationById(
    address upkeep,
    uint256 proposalId
  ) external onlyMaintenanceOrFundsAdmin {
    _disabledProposals[upkeep][proposalId] = !_disabledProposals[upkeep][proposalId];
  }

  /// @inheritdoc IAaveCLRobotOperator
  function isProposalDisabled(address upkeep, uint256 proposalId) external view returns (bool) {
    return _disabledProposals[upkeep][proposalId];
  }

  /// @inheritdoc IAaveCLRobotOperator
  function getFundsAdmin() external view returns (address) {
    return _fundsAdmin;
  }

  /// @inheritdoc IAaveCLRobotOperator
  function getMaintenanceAdmin() external view returns (address) {
    return _maintenanceAdmin;
  }

  /// @inheritdoc IAaveCLRobotOperator
  function getWithdrawAddress() external view returns (address) {
    return _linkWithdrawAddress;
  }

  /// @inheritdoc IAaveCLRobotOperator
  function getKeeperInfo(address upkeep) external view returns (KeeperInfo memory) {
    return _keepers[upkeep];
  }
}
