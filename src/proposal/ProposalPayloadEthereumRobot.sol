// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAaveCLRobotOperator} from '../interfaces/IAaveCLRobotOperator.sol';
import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveV2Ethereum, AaveV2EthereumAssets} from 'aave-address-book/AaveV2Ethereum.sol';
import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {SafeERC20} from 'solidity-utils/contracts/oz-common/SafeERC20.sol';

/**
 * @title ProposalPayloadEthereumRobot
 * @author BGD Labs
 * @dev Proposal to fund Chainlink Keeper for Governance Automation (gov v2)
 * - Transfer aLink tokens from collector to the short executor
 * - Withdraw aLink to get link token from the Aave v2 Pool
 * - Refill the Chainlink Keeper with link via the operator contract
 */
contract ProposalPayloadEthereumRobot {
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
    // transfer aLink from collector to the short executor
    AaveV3Ethereum.COLLECTOR.transfer(
      address(AaveV2EthereumAssets.LINK_A_TOKEN),
      address(this),
      LINK_AMOUNT
    );

    // withdraw aLink from the Aave V2 Pool
    AaveV2Ethereum.POOL.withdraw(
      address(AaveV2EthereumAssets.LINK_UNDERLYING),
      LINK_AMOUNT,
      address(this)
    );

    // approve link to the operator in order to refill the keeper
    IERC20(AaveV2EthereumAssets.LINK_UNDERLYING).forceApprove(
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
