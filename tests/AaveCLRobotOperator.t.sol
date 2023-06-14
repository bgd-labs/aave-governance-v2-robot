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
  address constant FUNDS_ADMIN = address(3);
  ILink constant LINK_TOKEN = ILink(0x514910771AF9Ca656af840dff83E8264EcF986CA);
  address constant MAINTENANCE_ADMIN = address(1);
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
      WITHDRAW_ADDRESS,
      FUNDS_ADMIN,
      MAINTENANCE_ADMIN
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
    (uint256 id, address upkeep) = _registerKeeper();
    (, , , uint96 previousBalance, , , , ) = IKeeperRegistry(REGISTRY).getUpkeep(id);
    uint96 amountToFund = 10 ether;

    vm.startPrank(LINK_WHALE);
    LINK_TOKEN.approve(address(aaveCLRobotOperator), amountToFund);
    aaveCLRobotOperator.refillKeeper(upkeep, amountToFund);
    vm.stopPrank();

    (, , , uint96 balance, , , , ) = IKeeperRegistry(REGISTRY).getUpkeep(id);
    assertEq(balance, previousBalance + amountToFund);
  }

  function testCancelAndWithdraw() public {
    assertEq(LINK_TOKEN.balanceOf(WITHDRAW_ADDRESS), 0);
    (uint256 id, address upkeep) = _registerKeeper();

    vm.startPrank(FUNDS_ADMIN);
    aaveCLRobotOperator.cancel(upkeep);
    vm.stopPrank();

    vm.roll(block.number + 100);

    aaveCLRobotOperator.withdrawLink(upkeep);
    (, , , uint96 balance, , , , ) = IKeeperRegistry(REGISTRY).getUpkeep(id);

    assertEq(balance, 0);
    assertGt(LINK_TOKEN.balanceOf(WITHDRAW_ADDRESS), 0);
  }

  function testCancel() public {
    (, address upkeep) = _registerKeeper();

    vm.startPrank(FUNDS_ADMIN);
    aaveCLRobotOperator.cancel(upkeep);
    vm.stopPrank();
  }

  function testChangeGasLimit(uint32 gasLimit) public {
    vm.assume(gasLimit >= 10_000 && gasLimit <= 5_000_000);
    (uint256 id, address upkeep) = _registerKeeper();

    vm.startPrank(MAINTENANCE_ADMIN);
    aaveCLRobotOperator.setGasLimit(upkeep, gasLimit);
    vm.stopPrank();

    vm.startPrank(address(6));
    vm.expectRevert('CALLER_NOT_MAINTENANCE_OR_FUNDS_ADMIN');
    aaveCLRobotOperator.setGasLimit(upkeep, gasLimit);
    vm.stopPrank();

    (, uint32 executeGas, , , , , , ) = IKeeperRegistry(REGISTRY).getUpkeep(id);
    assertEq(executeGas, gasLimit);
  }

  function testSetFundsAdmin(address fundsAdmin) public {
    vm.startPrank(FUNDS_ADMIN);
    aaveCLRobotOperator.setFundsAdmin(fundsAdmin);
    vm.stopPrank();

    vm.startPrank(address(10));
    vm.expectRevert('CALLER_NOT_FUNDS_ADMIN');
    aaveCLRobotOperator.setWithdrawAddress(fundsAdmin);
    vm.stopPrank();

    assertEq(aaveCLRobotOperator.getFundsAdmin(), fundsAdmin);
  }

  function testSetMaintenanceAdmin(address maintenanceAdmin) public {
    vm.startPrank(FUNDS_ADMIN);
    aaveCLRobotOperator.setMaintenanceAdmin(maintenanceAdmin);
    vm.stopPrank();

    vm.startPrank(address(10));
    vm.expectRevert('CALLER_NOT_MAINTENANCE_OR_FUNDS_ADMIN');
    aaveCLRobotOperator.setMaintenanceAdmin(maintenanceAdmin);
    vm.stopPrank();

    assertEq(aaveCLRobotOperator.getMaintenanceAdmin(), maintenanceAdmin);
  }

  function testSetWithdrawAddress(address newWithdrawAddress) public {
    vm.startPrank(FUNDS_ADMIN);
    aaveCLRobotOperator.setWithdrawAddress(newWithdrawAddress);
    vm.stopPrank();

    vm.startPrank(address(10));
    vm.expectRevert('CALLER_NOT_FUNDS_ADMIN');
    aaveCLRobotOperator.setWithdrawAddress(newWithdrawAddress);
    vm.stopPrank();

    assertEq(aaveCLRobotOperator.getWithdrawAddress(), newWithdrawAddress);
  }

  function testGetFundsAdmin() public {
    assertEq(aaveCLRobotOperator.getFundsAdmin(), FUNDS_ADMIN);
  }

  function testMaintenanceAdmin() public {
    assertEq(aaveCLRobotOperator.getMaintenanceAdmin(), MAINTENANCE_ADMIN);
  }

  function testGetWithdrawAddress() public {
    assertEq(aaveCLRobotOperator.getWithdrawAddress(), WITHDRAW_ADDRESS);
  }

  function testDisableAutomationById(address upkeep, uint256 proposalId) public {
    vm.startPrank(MAINTENANCE_ADMIN);
    assertEq(aaveCLRobotOperator.isProposalDisabled(upkeep, proposalId), false);

    aaveCLRobotOperator.toggleDisableAutomationById(upkeep, proposalId);

    assertEq(aaveCLRobotOperator.isProposalDisabled(upkeep, proposalId), true);

    aaveCLRobotOperator.toggleDisableAutomationById(upkeep, proposalId);

    assertEq(aaveCLRobotOperator.isProposalDisabled(upkeep, proposalId), false);
    vm.stopPrank();
  }

  function testGetKeeperInfo() public {
    (uint256 id, address upkeep) = _registerKeeper();
    AaveCLRobotOperator.KeeperInfo memory keeperInfo = aaveCLRobotOperator.getKeeperInfo(upkeep);
    assertEq(keeperInfo.id, id);
    assertEq(keeperInfo.registry, REGISTRY);
    assertEq(keeperInfo.name, 'testName');
  }

  function _registerKeeper() internal returns (uint256, address) {
    vm.startPrank(LINK_WHALE);
    LINK_TOKEN.transfer(FUNDS_ADMIN, 100 ether);
    vm.stopPrank();

    vm.startPrank(FUNDS_ADMIN);
    LINK_TOKEN.approve(address(aaveCLRobotOperator), 100 ether);
    EthRobotKeeper ethRobotKeeper = new EthRobotKeeper(
      address(AaveGovernanceV2.GOV),
      address(aaveCLRobotOperator)
    );
    uint256 id = aaveCLRobotOperator.register(
      'testName',
      address(ethRobotKeeper),
      1_000_000,
      '',
      100 ether,
      REGISTRY,
      REGISTRAR
    );
    vm.stopPrank();

    return (id, address(ethRobotKeeper));
  }
}
