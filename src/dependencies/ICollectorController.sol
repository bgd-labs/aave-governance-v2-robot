// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';

interface ICollectorController {
  /**
   * @dev Transfer an amount of tokens to the recipient.
   * @param collector The address of the collector contract to retrieve funds from (e.g. Aave ecosystem reserve)
   * @param token The address of the asset
   * @param recipient The address of the entity to transfer the tokens.
   * @param amount The amount to be transferred.
   */
  function transfer(address collector, address token, address recipient, uint256 amount) external;

  /**
   * @dev Transfer an amount of tokens to the recipient.
   * @param token The address of the asset
   * @param recipient The address of the entity to transfer the tokens.
   * @param amount The amount to be transferred.
   */
  function transfer(address token, address recipient, uint256 amount) external;
}
