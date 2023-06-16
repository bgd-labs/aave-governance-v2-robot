// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveCLRobotOperator} from '../contracts/AaveCLRobotOperator.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveV2Ethereum, AaveV2EthereumAssets} from 'aave-address-book/AaveV2Ethereum.sol';
import {LinkTokenInterface} from 'chainlink-brownie-contracts/interfaces/LinkTokenInterface.sol';

/**
 * @title ProposalPayloadEthereumRobot
 * @author BGD Labs
 * @dev Proposal to register Chainlink Keeper for ethereum governance v2
 * - Transfer aLink tokens from collector to the this address
 * - Withdraw Link to the operator contract
 * - Register the Chainlink Keeper for governance v2 via the operator contract
 */
contract ProposalPayloadEthereumRobot {
  address public immutable ETH_ROBOT_KEEPER_ADDRESS;
  address public immutable ETH_ROBOT_OPERATOR;
  uint256 public immutable LINK_AMOUNT;

  /**
   * @dev emitted when the new upkeep is registered in Chainlink
   * @param name name of the upkeep
   * @param upkeepId id of the upkeep in chainlink
   */
  event ChainlinkUpkeepRegistered(string indexed name, uint256 indexed upkeepId);

  /**
   * @dev constructor of the proposal
   * @param keeperAddress the address of the chainlink keeper
   * @param robotOperator the address of the aave chainlink robot operator
   * @param amountToFund the amount of link tokens to fund the keeper
   */
  constructor(address keeperAddress, address robotOperator, uint256 amountToFund) {
    ETH_ROBOT_KEEPER_ADDRESS = keeperAddress;
    ETH_ROBOT_OPERATOR = robotOperator;
    LINK_AMOUNT = amountToFund;
  }

  function execute() external {
    // transfer aLink from collector to this address
    AaveV3Ethereum.COLLECTOR.transfer(
      address(AaveV2EthereumAssets.LINK_A_TOKEN),
      address(this),
      LINK_AMOUNT
    );

    // withdraw link to the operator contract
    AaveV2Ethereum.POOL.withdraw(
      address(AaveV2EthereumAssets.LINK_UNDERLYING),
      LINK_AMOUNT,
      address(this)
    );

    // approve Link to the operator in order to register
    LinkTokenInterface(AaveV2EthereumAssets.LINK_UNDERLYING).approve(
      ETH_ROBOT_OPERATOR,
      LINK_AMOUNT
    );

    // register the keeper via the operator
    uint256 id = AaveCLRobotOperator(ETH_ROBOT_OPERATOR).register(
      'AaveEthRobotKeeperV2',
      ETH_ROBOT_KEEPER_ADDRESS,
      2_000_000,
      safeToUint96(LINK_AMOUNT)
    );
    emit ChainlinkUpkeepRegistered('AaveEthRobotKeeperV2', id);
  }

  function safeToUint96(uint256 value) internal pure returns (uint96) {
    require(value <= type(uint96).max, 'Value doesnt fit in 96 bits');
    return uint96(value);
  }
}
