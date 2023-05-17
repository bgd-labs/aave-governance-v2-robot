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
  mapping(address upkeep => KeeperInfo) public keepers;
  address public immutable LINK_TOKEN;

  address public _fundsAdmin;
  address public _maintenanceAdmin;
  address public _linkWithdrawAddress;

  mapping(address upkeep =>
    mapping(uint256 proposalId => bool isDisabled)
  ) internal _disabledProposals;

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
      msg.sender == _maintenanceAdmin ||
      msg.sender == _fundsAdmin
      ,
       'CALLER_NOT_MAINTENANCE_OR_FUNDS_ADMIN'
    );
    _;
  }

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

  function register(
    string memory name,
    address upkeepContract,
    uint32 gasLimit,
    bytes memory checkData,
    uint96 amountToFund,
    address keeperRegistry,
    address keeperRegistrar
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
      keeperRegistrar,
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
      keepers[upkeepContract].id = id;
      keepers[upkeepContract].name = name;
      keepers[upkeepContract].registry = keeperRegistry;
      keepers[upkeepContract].registrer = keeperRegistrar;
      return id;
    } else {
      revert('AUTO_APPROVE_DISABLED');
    }
  }

  function cancel(address upkeep) external onlyFundsAdmin {
    IKeeperRegistry(keepers[upkeep].registry).cancelUpkeep(keepers[upkeep].id);
  }

  function withdrawLink(address upkeep) external {
    IKeeperRegistry(keepers[upkeep].registry).withdrawFunds(
      keepers[upkeep].id,
      _linkWithdrawAddress
    );
  }

  function setGasLimit(address upkeep, uint32 gasLimit) external onlyMaintenanceOrFundsAdmin {
    IKeeperRegistry(keepers[upkeep].registry).setUpkeepGasLimit(
      keepers[upkeep].id,
      gasLimit
    );
  }

  function setWithdrawAddress(address newWithdrawAddress) external onlyFundsAdmin {
    _linkWithdrawAddress = newWithdrawAddress;
  }

  function disableAutomationById(
    address upkeep,
    uint256 proposalId
  ) external onlyMaintenanceOrFundsAdmin {
    _disabledProposals[upkeep][proposalId] = true;
  }

  function isProposalDisabled(
    address upkeep,
    uint256 proposalId
  ) public view returns (bool) {
    return _disabledProposals[upkeep][proposalId];
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
