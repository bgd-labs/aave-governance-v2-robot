// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAaveCLRobotOperator} from '../interfaces/IAaveCLRobotOperator.sol';
import {AaveV3Arbitrum, AaveV3ArbitrumAssets} from 'aave-address-book/AaveV3Arbitrum.sol';
import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {SafeERC20} from 'solidity-utils/contracts/oz-common/SafeERC20.sol';

/**
 * @title ProposalPayloadArbitrumRobot
 * @author BGD Labs
 * @dev Proposal to fund Chainlink Keeper for Arbitrum Bridge Executor Automation (gov v2)
 * - Transfer aLink tokens from AAVE Collector to the bridge executor
 * - Withdraw aLink to get link token from the Aave v3 Pool
 * - Refill the Chainlink Keeper with link via the operator contract
 */
contract ProposalPayloadArbitrumRobot {
  using SafeERC20 for IERC20;

  address public immutable ROBOT_OPERATOR;
  uint256 public immutable LINK_AMOUNT;
  uint256 public immutable KEEPER_ID;

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
    // transfer aLink from collector to the bridge executor
    AaveV3Arbitrum.COLLECTOR.transfer(
      address(AaveV3ArbitrumAssets.LINK_A_TOKEN),
      address(this),
      LINK_AMOUNT
    );

    // withdraw aLink from the Aave V3 Pool
    AaveV3Arbitrum.POOL.withdraw(AaveV3ArbitrumAssets.LINK_UNDERLYING, LINK_AMOUNT, address(this));

    // approve link to the operator in order to refill the keeper
    IERC20(AaveV3ArbitrumAssets.LINK_UNDERLYING).forceApprove(
      ROBOT_OPERATOR,
      LINK_AMOUNT
    );

    // refills the keeper with link
    IAaveCLRobotOperator(ROBOT_OPERATOR).refillKeeper(
      KEEPER_ID,
      safeToUint96(LINK_AMOUNT)
    );
  }

  function safeToUint96(uint256 value) internal pure returns (uint96) {
    require(value <= type(uint96).max, 'Value doesnt fit in 96 bits');
    return uint96(value);
  }
}
