// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LinkTokenInterface} from 'chainlink-brownie-contracts/interfaces/LinkTokenInterface.sol';
import {AutomationRegistryInterface, Config, State} from 'chainlink-brownie-contracts/interfaces/AutomationRegistryInterface1_2.sol';
import {KeeperRegistrarInterface} from './KeeperRegistrarInterface.sol';
import {ICollectorController} from '../dependencies/ICollectorController.sol';
import {AaveV3Polygon, AaveV3PolygonAssets} from 'aave-address-book/AaveV3Polygon.sol';
import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';

/**
 * @title ProposalPayloadPolygonRobot
 * @author BGD Labs
 * @dev Proposal to register Chainlink Keeper for Polygon Bridge Executor
 * - Transfer ERC-677 LINK tokens from AAVE treasury to the current address
 * - Register the Chainlink Keeper for Polygon Bridge Executor
 */
contract ProposalPayloadPolygonRobot {
  address public constant KEEPER_REGISTRAR_ADDRESS =
    address(0xDb8e8e2ccb5C033938736aa89Fe4fa1eDfD15a1d);

  AutomationRegistryInterface public constant KEEPER_REGISTRY =
    AutomationRegistryInterface(0x02777053d6764996e594c3E88AF1D58D5363a2e6);

  LinkTokenInterface public constant ERC677_LINK =
    LinkTokenInterface(0xb0897686c545045aFc77CF20eC7A532E3120E0F1);

  ICollectorController public immutable collectorController;
  address public immutable POLYGON_ROBOT_KEEPER_ADDRESS;
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
   * @param amountToFund the amount of link tokens to fund the keeper
   */
  constructor(address keeperAddress, uint256 amountToFund) {
    collectorController = ICollectorController(address(AaveV3Polygon.COLLECTOR_CONTROLLER));

    POLYGON_ROBOT_KEEPER_ADDRESS = keeperAddress;
    LINK_AMOUNT = amountToFund;
  }

  function execute() external {
    // Transfer ERC-677 from treasury to this address
    collectorController.transfer(
      AaveV3Polygon.COLLECTOR,
      address(ERC677_LINK),
      address(this),
      LINK_AMOUNT
    );

    // create chainlink upkeep for polygon governance robot
    registerUpkeep(
      'AavePolygonRobotKeeperV2',
      POLYGON_ROBOT_KEEPER_ADDRESS,
      5000000,
      address(this),
      abi.encode(),
      safeToUint96(LINK_AMOUNT)
    );
  }

  /**
   * @dev register keeper contract in chainlink
   * @param name name of the upkeep
   * @param upkeepContract the address of the keeper contract
   * @param gasLimit gas limit
   * @param adminAddress the address of the admin
   * @param checkData params for the check method
   * @param amount amount of LINK for the upkeep
   */
  function registerUpkeep(
    string memory name,
    address upkeepContract,
    uint32 gasLimit,
    address adminAddress,
    bytes memory checkData,
    uint96 amount
  ) internal {
    (State memory state, Config memory _c, address[] memory _k) = KEEPER_REGISTRY.getState();
    uint256 oldNonce = state.nonce;
    bytes memory payload = abi.encode(
      name,
      0x0,
      upkeepContract,
      gasLimit,
      adminAddress,
      checkData,
      amount,
      0,
      address(this)
    );

    bytes4 registerSig = KeeperRegistrarInterface.register.selector;

    ERC677_LINK.transferAndCall(
      KEEPER_REGISTRAR_ADDRESS,
      amount,
      bytes.concat(registerSig, payload)
    );

    (state, _c, _k) = KEEPER_REGISTRY.getState();

    if (state.nonce == oldNonce + 1) {
      uint256 upkeepID = uint256(
        keccak256(
          abi.encodePacked(blockhash(block.number - 1), address(KEEPER_REGISTRY), uint32(oldNonce))
        )
      );

      emit ChainlinkUpkeepRegistered(name, upkeepID);
    } else {
      revert('auto-approve disabled');
    }
  }

  function safeToUint96(uint256 value) internal pure returns (uint96) {
    require(value <= type(uint96).max, 'Value doesnt fit in 96 bits');
    return uint96(value);
  }
}
