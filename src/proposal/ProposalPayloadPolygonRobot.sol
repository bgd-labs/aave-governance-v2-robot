// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LinkTokenInterface} from 'chainlink-brownie-contracts/interfaces/LinkTokenInterface.sol';
import {AaveV3Polygon} from 'aave-address-book/AaveV3Polygon.sol';
import {AaveCLRobotOperator} from '../contracts/AaveCLRobotOperator.sol';

/**
 * @title ProposalPayloadPolygonRobot
 * @author BGD Labs
 * @dev Proposal to register Chainlink Keeper for Polygon Bridge Executor
 * - Transfer ERC-677 LINK tokens from the collector to the robot operator contract
 * - Register the Chainlink Keeper for polygon bridge executor via the operator contract
 */
contract ProposalPayloadPolygonRobot {
  address public constant KEEPER_REGISTRAR_ADDRESS = 0xDb8e8e2ccb5C033938736aa89Fe4fa1eDfD15a1d;
  address public constant KEEPER_REGISTRY = 0x02777053d6764996e594c3E88AF1D58D5363a2e6;

  address public constant ERC677_LINK = 0xb0897686c545045aFc77CF20eC7A532E3120E0F1;

  address public immutable POLYGON_ROBOT_KEEPER_ADDRESS;
  address public immutable POLYGON_ROBOT_OPERATOR;
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
    POLYGON_ROBOT_KEEPER_ADDRESS = keeperAddress;
    POLYGON_ROBOT_OPERATOR = robotOperator;
    LINK_AMOUNT = amountToFund;
  }

  function execute() external {
    // transfer ERC-677 Link from collector to the robot operator address
    AaveV3Polygon.COLLECTOR.transfer(
      ERC677_LINK,
      POLYGON_ROBOT_OPERATOR,
      LINK_AMOUNT
    );

    // register the keeper via the operator
    uint256 id = AaveCLRobotOperator(POLYGON_ROBOT_OPERATOR).register(
      'AavePolRobotKeeperV2',
      POLYGON_ROBOT_KEEPER_ADDRESS,
      5_000_000,
      '',
      safeToUint96(LINK_AMOUNT),
      KEEPER_REGISTRY,
      KEEPER_REGISTRAR_ADDRESS
    );
    emit ChainlinkUpkeepRegistered('AavePolRobotKeeperV2', id);
  }

  function safeToUint96(uint256 value) internal pure returns (uint96) {
    require(value <= type(uint96).max, 'Value doesnt fit in 96 bits');
    return uint96(value);
  }
}
