// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveCLRobotOperator} from '../contracts/AaveCLRobotOperator.sol';
import {AaveV3Arbitrum, AaveV3ArbitrumAssets} from 'aave-address-book/AaveV3Arbitrum.sol';
import {LinkTokenInterface} from 'chainlink-brownie-contracts/interfaces/LinkTokenInterface.sol';

/**
 * @title ProposalPayloadArbitrumRobot
 * @author BGD Labs
 * @dev Proposal to register Chainlink Keeper for Arbitrum Bridge Executor
 * - Transfer aLink tokens from AAVE Collector to the current address
 * - Withdraw aLink to get Link token to the operator address
 * - Register the Chainlink Keeper for arbitrum bridge executor via the operator contract
 */
contract ProposalPayloadArbitrumRobot {
  address public constant KEEPER_REGISTRAR_ADDRESS = 0x4F3AF332A30973106Fe146Af0B4220bBBeA748eC;
  address public constant KEEPER_REGISTRY = 0x75c0530885F385721fddA23C539AF3701d6183D4;

  address public immutable ARBITRUM_ROBOT_KEEPER_ADDRESS;
  address public immutable ARBITRUM_ROBOT_OPERATOR;
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
    ARBITRUM_ROBOT_KEEPER_ADDRESS = keeperAddress;
    ARBITRUM_ROBOT_OPERATOR = robotOperator;
    LINK_AMOUNT = amountToFund;
  }

  function execute() external {
    // transfer aLink from collector to this address
    AaveV3Arbitrum.COLLECTOR.transfer(
      address(AaveV3ArbitrumAssets.LINK_A_TOKEN),
      address(this),
      LINK_AMOUNT
    );

    // withdraw aLink from the Aave V3 Pool
    AaveV3Arbitrum.POOL.withdraw(
      AaveV3ArbitrumAssets.LINK_UNDERLYING,
      LINK_AMOUNT,
      address(this)
    );

    // approve Link to the operator in order to register
    LinkTokenInterface(AaveV3ArbitrumAssets.LINK_UNDERLYING).approve(ARBITRUM_ROBOT_OPERATOR, LINK_AMOUNT);

    // register the keeper via the operator
    uint256 id = AaveCLRobotOperator(ARBITRUM_ROBOT_OPERATOR).register(
      'AaveArbRobotKeeperV2',
      ARBITRUM_ROBOT_KEEPER_ADDRESS,
      5_000_000,
      '',
      safeToUint96(LINK_AMOUNT),
      KEEPER_REGISTRY,
      KEEPER_REGISTRAR_ADDRESS
    );
    emit ChainlinkUpkeepRegistered('AaveArbRobotKeeperV2', id);
  }

  function safeToUint96(uint256 value) internal pure returns (uint96) {
    require(value <= type(uint96).max, 'Value doesnt fit in 96 bits');
    return uint96(value);
  }
}
