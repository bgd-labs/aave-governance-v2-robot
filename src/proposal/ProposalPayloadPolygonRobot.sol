// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LinkTokenInterface} from 'chainlink-brownie-contracts/interfaces/LinkTokenInterface.sol';
import {AaveV3Polygon, AaveV3PolygonAssets} from 'aave-address-book/AaveV3Polygon.sol';
import {AaveCLRobotOperator} from '../contracts/AaveCLRobotOperator.sol';
import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {IPegSwap} from '../dependencies/IPegSwap.sol';

/**
 * @title ProposalPayloadPolygonRobot
 * @author BGD Labs
 * @dev Proposal to register Chainlink Keeper for Polygon Bridge Executor
 * - Transfer aLink tokens from AAVE treasury to the current address
 * - Withdraw aLink to get ERC-20 LINK
 * - Swaps ERC-20 LINK to ERC-677 LINK using Chainlink PegSwap
 * - Register the Chainlink Keeper for polygon bridge executor via the operator contract
 */
contract ProposalPayloadPolygonRobot {
  address public constant KEEPER_REGISTRAR_ADDRESS = 0xDb8e8e2ccb5C033938736aa89Fe4fa1eDfD15a1d;
  address public constant KEEPER_REGISTRY = 0x02777053d6764996e594c3E88AF1D58D5363a2e6;

  LinkTokenInterface public constant ERC677_LINK =
    LinkTokenInterface(0xb0897686c545045aFc77CF20eC7A532E3120E0F1);

  address public immutable POLYGON_ROBOT_KEEPER_ADDRESS;
  address public immutable POLYGON_ROBOT_OPERATOR;
  uint256 public immutable LINK_AMOUNT;

  IPegSwap public constant PEGSWAP = IPegSwap(0xAA1DC356dc4B18f30C347798FD5379F3D77ABC5b);

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
    // transfer aLink from collector to this address
    AaveV3Polygon.COLLECTOR.transfer(AaveV3PolygonAssets.LINK_A_TOKEN, address(this), LINK_AMOUNT);

    // Withdraw aLink from the Aave V3 Pool
    AaveV3Polygon.POOL.withdraw(AaveV3PolygonAssets.LINK_UNDERLYING, LINK_AMOUNT, address(this));

    // Swap ERC-20 Link to ERC-677 Link
    IERC20(AaveV3PolygonAssets.LINK_UNDERLYING).approve(address(PEGSWAP), LINK_AMOUNT);
    PEGSWAP.swap(LINK_AMOUNT, AaveV3PolygonAssets.LINK_UNDERLYING, address(ERC677_LINK));

    // approve Link to the operator in order to register
    ERC677_LINK.approve(POLYGON_ROBOT_OPERATOR, LINK_AMOUNT);

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
