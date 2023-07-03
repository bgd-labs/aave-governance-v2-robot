// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {AaveCLRobotOperator} from '../src/contracts/AaveCLRobotOperator.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {LinkTokenInterface as ILink} from 'chainlink-brownie-contracts/interfaces/LinkTokenInterface.sol';
import {EthRobotKeeper} from '../src/contracts/EthRobotKeeper.sol';
import {IKeeperRegistry} from '../src/interfaces/IKeeperRegistry.sol';
import 'forge-std/console.sol';

contract AaveCLRobotOperatorTest is Test {
  AaveCLRobotOperator public aaveCLRobotOperator;
  address constant LINK_WHALE = 0xF977814e90dA44bFA03b6295A0616a897441aceC;
  ILink constant LINK_TOKEN = ILink(0x514910771AF9Ca656af840dff83E8264EcF986CA);
  address constant WITHDRAW_ADDRESS = address(2);
  address constant REGISTRY = 0x02777053d6764996e594c3E88AF1D58D5363a2e6;
  address constant REGISTRAR = 0xDb8e8e2ccb5C033938736aa89Fe4fa1eDfD15a1d;

  function setUp() public {
    vm.createSelectFork(
      'mainnet',
      17273246 // May-16-2023
    );
    aaveCLRobotOperator = new AaveCLRobotOperator(
      address(LINK_TOKEN),
      REGISTRY,
      REGISTRAR,
      WITHDRAW_ADDRESS,
      AaveGovernanceV2.SHORT_EXECUTOR
    );
  }

  function testRegister() public {
    (uint256 id, address upkeep) = _registerKeeper();
    (
      address target,
      uint32 executeGas,
      bytes memory checkData,
      uint96 balance,
      ,
      address admin,
      ,

    ) = IKeeperRegistry(REGISTRY).getUpkeep(id);

    assertEq(target, upkeep);
    assertEq(executeGas, 1000000);
    assertEq(checkData, '');
    assertEq(balance, 100 ether);
    assertEq(admin, address(aaveCLRobotOperator));
  }

  function testRefill() public {
    (uint256 id, ) = _registerKeeper();
    (, , , uint96 previousBalance, , , , ) = IKeeperRegistry(REGISTRY).getUpkeep(id);
    uint96 amountToFund = 10 ether;

    vm.startPrank(LINK_WHALE);
    LINK_TOKEN.approve(address(aaveCLRobotOperator), amountToFund);
    aaveCLRobotOperator.refillKeeper(id, amountToFund);
    vm.stopPrank();

    (, , , uint96 balance, , , , ) = IKeeperRegistry(REGISTRY).getUpkeep(id);
    assertEq(balance, previousBalance + amountToFund);
  }

  function testCancelAndWithdraw() public {
    assertEq(LINK_TOKEN.balanceOf(WITHDRAW_ADDRESS), 0);
    (uint256 id, ) = _registerKeeper();

    vm.startPrank(aaveCLRobotOperator.owner());
    aaveCLRobotOperator.cancel(id);
    vm.stopPrank();

    vm.roll(block.number + 100);

    aaveCLRobotOperator.withdrawLink(id);
    (, , , uint96 balance, , , , ) = IKeeperRegistry(REGISTRY).getUpkeep(id);

    assertEq(balance, 0);
    assertGt(LINK_TOKEN.balanceOf(WITHDRAW_ADDRESS), 0);
  }

  function testCancel() public {
    (uint256 id, ) = _registerKeeper();

    vm.startPrank(aaveCLRobotOperator.owner());
    aaveCLRobotOperator.cancel(id);
    vm.stopPrank();
  }

  function testChangeGasLimit(uint32 gasLimit) public {
    vm.assume(gasLimit >= 10_000 && gasLimit <= 5_000_000);
    (uint256 id, ) = _registerKeeper();

    vm.startPrank(aaveCLRobotOperator.guardian());
    aaveCLRobotOperator.setGasLimit(id, gasLimit);
    vm.stopPrank();

    vm.startPrank(address(6));
    vm.expectRevert(bytes('ONLY_BY_OWNER_OR_GUARDIAN'));
    aaveCLRobotOperator.setGasLimit(id, gasLimit);
    vm.stopPrank();

    (, uint32 executeGas, , , , , , ) = IKeeperRegistry(REGISTRY).getUpkeep(id);
    assertEq(executeGas, gasLimit);
  }

  function testSetWithdrawAddress(address newWithdrawAddress) public {
    vm.startPrank(aaveCLRobotOperator.owner());
    aaveCLRobotOperator.setWithdrawAddress(newWithdrawAddress);
    vm.stopPrank();

    vm.startPrank(address(10));
    vm.expectRevert(bytes('Ownable: caller is not the owner'));
    aaveCLRobotOperator.setWithdrawAddress(newWithdrawAddress);
    vm.stopPrank();

    assertEq(aaveCLRobotOperator.getWithdrawAddress(), newWithdrawAddress);
  }

  function testGetWithdrawAddress() public {
    assertEq(aaveCLRobotOperator.getWithdrawAddress(), WITHDRAW_ADDRESS);
  }

  function testGetKeeperInfo() public {
    (uint256 id, address upkeep) = _registerKeeper();
    AaveCLRobotOperator.KeeperInfo memory keeperInfo = aaveCLRobotOperator.getKeeperInfo(id);
    assertEq(keeperInfo.upkeep, upkeep);
    assertEq(keeperInfo.name, 'testName');
  }

  function _registerKeeper() internal returns (uint256, address) {
    vm.startPrank(LINK_WHALE);
    LINK_TOKEN.transfer(AaveGovernanceV2.SHORT_EXECUTOR, 100 ether);
    vm.stopPrank();

    vm.startPrank(AaveGovernanceV2.SHORT_EXECUTOR);
    LINK_TOKEN.approve(address(aaveCLRobotOperator), 100 ether);
    EthRobotKeeper ethRobotKeeper = new EthRobotKeeper(
      address(AaveGovernanceV2.GOV)
    );
    uint256 id = aaveCLRobotOperator.register(
      'testName',
      address(ethRobotKeeper),
      1_000_000,
      100 ether
    );
    vm.stopPrank();

    return (id, address(ethRobotKeeper));
  }
}
