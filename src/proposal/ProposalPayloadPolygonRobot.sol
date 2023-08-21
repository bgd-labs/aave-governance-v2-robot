// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Polygon, AaveV3PolygonAssets} from 'aave-address-book/AaveV3Polygon.sol';
import {IAaveCLRobotOperator} from '../interfaces/IAaveCLRobotOperator.sol';
import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {SafeERC20} from 'solidity-utils/contracts/oz-common/SafeERC20.sol';
import {SafeCast} from 'solidity-utils/contracts/oz-common/SafeCast.sol';
import {IPegSwap} from '../dependencies/IPegSwap.sol';

/**
 * @title ProposalPayloadPolygonRobot
 * @author BGD Labs
 * @dev PProposal to fund Chainlink Keeper for Polygon Bridge Executor Automation (gov v2)
 * - Transfer aLink tokens from AAVE treasury to the bridge executor
 * - Withdraw aLink to get ERC-20 link
 * - Swaps ERC-20 link to ERC-677 link using Chainlink PegSwap
 * - Refill the Chainlink Keeper with link via the operator contract
 */
contract ProposalPayloadPolygonRobot {
  using SafeERC20 for IERC20;
  using SafeCast for uint256;

  address public constant ERC677_LINK = 0xb0897686c545045aFc77CF20eC7A532E3120E0F1;
  address public immutable ROBOT_OPERATOR;
  uint256 public immutable LINK_AMOUNT;
  uint256 public immutable KEEPER_ID;

  IPegSwap public constant PEGSWAP = IPegSwap(0xAA1DC356dc4B18f30C347798FD5379F3D77ABC5b);

  /**
   * @dev constructor of the proposal
   * @param keeperId the chainlink id of the pre-registered keeper.
   * @param robotOperator the address of the aave chainlink robot operator
   * @param amountToFund the amount of link tokens to fund the keeper
   */
  constructor(uint256 keeperId, address robotOperator, uint256 amountToFund) {
    KEEPER_ID = keeperId;
    ROBOT_OPERATOR = robotOperator;
    LINK_AMOUNT = amountToFund;
  }

  function execute() external {
    // transfer aLink from collector to this address
    AaveV3Polygon.COLLECTOR.transfer(AaveV3PolygonAssets.LINK_A_TOKEN, address(this), LINK_AMOUNT);

    // Withdraw aLink from the Aave V3 Pool
    AaveV3Polygon.POOL.withdraw(AaveV3PolygonAssets.LINK_UNDERLYING, LINK_AMOUNT, address(this));

    // Swap ERC-20 link to ERC-677 link
    IERC20(AaveV3PolygonAssets.LINK_UNDERLYING).forceApprove(address(PEGSWAP), LINK_AMOUNT);
    PEGSWAP.swap(LINK_AMOUNT, AaveV3PolygonAssets.LINK_UNDERLYING, ERC677_LINK);

    // approve link to the operator in order to register
    IERC20(ERC677_LINK).forceApprove(ROBOT_OPERATOR, LINK_AMOUNT);

    // refills the keeper with link
    IAaveCLRobotOperator(ROBOT_OPERATOR).refillKeeper(
      KEEPER_ID,
      LINK_AMOUNT.toUint96()
    );
  }
}
