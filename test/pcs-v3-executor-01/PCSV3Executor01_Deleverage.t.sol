// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/Test.sol";

import { PCSV3Executor01 } from "src/executors/PCSV3Executor01.sol";
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { PancakeV3VaultOracle } from "src/oracles/PancakeV3VaultOracle.sol";
import { Bank } from "src/Bank.sol";
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "test/fixtures/BscFixture.f.sol";

contract PCSV3Executor01DeleverageForkTest is BscFixture {
  address manager = 0x6EB9bC094CC57e56e91f3bec4BFfe7D9B1802e38;
  Bank bank = Bank(0xD0dfE9277B1DB02187557eAeD7e25F74eF2DE8f3);
  AutomatedVaultManager avManager = AutomatedVaultManager(0x2A9614504A12de8a85207199CdE1860269411F71);
  PCSV3Executor01 executor = PCSV3Executor01(0x7B33803D350293b271080ea78bE9CB0395d6d7E1);
  PancakeV3VaultOracle oracle = PancakeV3VaultOracle(0xa51b8f7dF8474111C6beA5eB2Fe60061C03FCEaf);
  ProxyAdmin proxyAdmin = ProxyAdmin(0x743a4c3f70C629a8BB27c8cf61651fc7BfC25c27);
  address L_USDTBNB_05_PCS1 = 0xb08eE41e88A2820cd572B4f2DFc459549790F2D7;
  address L_USDTBNB_05_PCS1_WORKER = 0x463039266657602f60fc70De00553772f3cf4392;

  uint256 USDT_DEBT_AT_FORK_BLOCK = 1677155473089924601649864;
  uint256 WBNB_DEBT_AT_FORK_BLOCK = 971261216631170;

  constructor() BscFixture() {
    uint256 FORK_BLOCK_NUMBER = 30954637;
    vm.createSelectFork("bsc_mainnet", FORK_BLOCK_NUMBER);

    address newBank = address(new Bank());
    address newPCSV3Executor01 = address(new PCSV3Executor01());

    // upgrade Bank and Executor
    vm.startPrank(0xC44f82b07Ab3E691F826951a6E335E1bC1bB0B51);
    proxyAdmin.upgrade(ITransparentUpgradeableProxy(address(bank)), newBank);
    proxyAdmin.upgrade(ITransparentUpgradeableProxy(address(executor)), newPCSV3Executor01);
    // tolerance 1%
    avManager.setToleranceBps(L_USDTBNB_05_PCS1, 9900);
    vm.stopPrank();
  }

  function testFuzz_WhenDeleverage_DebtRatioShouldDecrease(uint256 _positionBps) public {
    _positionBps = bound(_positionBps, 1, 2500);

    bytes[] memory manageBytes = new bytes[](1);
    manageBytes[0] = abi.encodeCall(PCSV3Executor01.deleverage, (L_USDTBNB_05_PCS1, _positionBps));

    (uint256 usdtDebtBefore, uint256 wbnbDebtBefore, uint256 debtRatioBefore) = getVaultDebtAndDebtRatio();

    vm.prank(manager);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);

    (uint256 usdtDebtAfter, uint256 wbnbDebtAfter, uint256 debtRatioAfter) = getVaultDebtAndDebtRatio();
    assertLt(usdtDebtAfter, usdtDebtBefore);
    assertLt(wbnbDebtAfter, wbnbDebtBefore);
    assertLt(debtRatioAfter, debtRatioBefore);
  }

  function testCorrectness_WhenDeleverage_WithoutSwap() public {
    (uint256 usdtDebtBefore, uint256 wbnbDebtBefore, uint256 debtRatioBefore) = getVaultDebtAndDebtRatio();
    bytes[] memory manageBytes = new bytes[](1);
    // patial close only 0.01%
    manageBytes[0] = abi.encodeCall(PCSV3Executor01.deleverage, (L_USDTBNB_05_PCS1, 1));

    vm.prank(manager);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);

    (uint256 usdtDebtAfter, uint256 wbnbDebtAfter, uint256 debtRatioAfter) = getVaultDebtAndDebtRatio();

    assertLt(usdtDebtAfter, usdtDebtBefore);
    assertLt(wbnbDebtAfter, wbnbDebtBefore);
    assertLt(debtRatioAfter, debtRatioBefore);
  }

  function testCorrectness_WhenDeleverage_NeedToSwapZeroForOne() public {
    // repay all usdt debt
    deal(address(usdt), address(executor), USDT_DEBT_AT_FORK_BLOCK);
    vm.mockCall(address(avManager), abi.encodeWithSignature("EXECUTOR_IN_SCOPE()"), abi.encode(address(executor)));

    vm.startPrank(address(executor));
    usdt.approve(address(bank), USDT_DEBT_AT_FORK_BLOCK);
    bank.repayOnBehalfOf(L_USDTBNB_05_PCS1, address(usdt), USDT_DEBT_AT_FORK_BLOCK);
    vm.stopPrank();

    (uint256 usdtDebtBefore, uint256 wbnbDebtBefore, uint256 debtRatioBefore) = getVaultDebtAndDebtRatio();
    bytes[] memory manageBytes = new bytes[](1);
    // patial close only 25% of positions
    manageBytes[0] = abi.encodeCall(PCSV3Executor01.deleverage, (L_USDTBNB_05_PCS1, 2500));

    vm.prank(manager);

    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);

    (uint256 usdtDebtAfter, uint256 wbnbDebtAfter, uint256 debtRatioAfter) = getVaultDebtAndDebtRatio();

    assertLt(usdtDebtAfter, usdtDebtBefore);
    assertLt(wbnbDebtAfter, wbnbDebtBefore);
    assertLt(debtRatioAfter, debtRatioBefore);
  }

  function testCorrectness_WhenDeleverage_NeedToSwapOneForZero() public {
    // repay all wbnb debt
    deal(address(wbnb), address(executor), WBNB_DEBT_AT_FORK_BLOCK);
    vm.mockCall(address(avManager), abi.encodeWithSignature("EXECUTOR_IN_SCOPE()"), abi.encode(address(executor)));

    vm.startPrank(address(executor));
    wbnb.approve(address(bank), WBNB_DEBT_AT_FORK_BLOCK);
    bank.repayOnBehalfOf(L_USDTBNB_05_PCS1, address(wbnb), WBNB_DEBT_AT_FORK_BLOCK);
    vm.stopPrank();

    (uint256 usdtDebtBefore, uint256 wbnbDebtBefore, uint256 debtRatioBefore) = getVaultDebtAndDebtRatio();
    bytes[] memory manageBytes = new bytes[](1);
    // patial close only 25% of positions
    manageBytes[0] = abi.encodeCall(PCSV3Executor01.deleverage, (L_USDTBNB_05_PCS1, 2500));

    vm.prank(manager);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);

    (uint256 usdtDebtAfter, uint256 wbnbDebtAfter, uint256 debtRatioAfter) = getVaultDebtAndDebtRatio();

    assertLt(usdtDebtAfter, usdtDebtBefore);
    assertLt(wbnbDebtAfter, wbnbDebtBefore);
    assertLt(debtRatioAfter, debtRatioBefore);
  }

  function testCorrectness_WhenDeleverage_WithMaxBps_ShouldWork() external {
    vm.prank(0xC44f82b07Ab3E691F826951a6E335E1bC1bB0B51);
    avManager.setToleranceBps(L_USDTBNB_05_PCS1, 9500);

    // decrease position multiple times
    bytes[] memory manageBytes = new bytes[](1);
    manageBytes[0] = abi.encodeCall(PCSV3Executor01.deleverage, (L_USDTBNB_05_PCS1, 5000));
    vm.prank(manager);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);

    manageBytes[0] = abi.encodeCall(PCSV3Executor01.deleverage, (L_USDTBNB_05_PCS1, 5000));
    vm.prank(manager);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);

    manageBytes[0] = abi.encodeCall(PCSV3Executor01.deleverage, (L_USDTBNB_05_PCS1, 5000));
    vm.prank(manager);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);

    manageBytes[0] = abi.encodeCall(PCSV3Executor01.deleverage, (L_USDTBNB_05_PCS1, 5000));
    vm.prank(manager);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);

    manageBytes[0] = abi.encodeCall(PCSV3Executor01.deleverage, (L_USDTBNB_05_PCS1, 10000));
    vm.prank(manager);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);

    // try close position with liquidity = 0
    manageBytes[0] = abi.encodeCall(PCSV3Executor01.closePosition, ());
    vm.prank(manager);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);
  }

  function testCorrectness_Deleverage_WhenNoOpenPosition() external {
    vm.prank(0xC44f82b07Ab3E691F826951a6E335E1bC1bB0B51);
    avManager.setToleranceBps(L_USDTBNB_05_PCS1, 9500);

    bytes[] memory manageBytes = new bytes[](1);
    manageBytes[0] = abi.encodeCall(PCSV3Executor01.closePosition, ());

    vm.prank(manager);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);

    uint256 usdtWorkerBalanceBefore = usdt.balanceOf(L_USDTBNB_05_PCS1_WORKER);
    uint256 wbnbWorkerBalanceBefore = wbnb.balanceOf(L_USDTBNB_05_PCS1_WORKER);

    (uint256 usdtDebtBefore, uint256 wbnbDebtBefore,) = getVaultDebtAndDebtRatio();

    uint256 _partialCloseBps = 1000;

    manageBytes[0] = abi.encodeCall(PCSV3Executor01.deleverage, (L_USDTBNB_05_PCS1, _partialCloseBps));
    vm.prank(manager);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);

    (uint256 usdtDebtAfter, uint256 wbnbDebtAfter,) = getVaultDebtAndDebtRatio();

    uint256 usdtToExecutor = usdtWorkerBalanceBefore * _partialCloseBps / 10000;
    uint256 wbnbToExecutor = wbnbWorkerBalanceBefore * _partialCloseBps / 10000;

    // debt should be repaid at least the amount that transfer to executor
    assertLe(usdtDebtAfter, usdtDebtBefore < usdtToExecutor ? 0 : usdtDebtBefore - usdtToExecutor);
    assertLe(wbnbDebtAfter, wbnbDebtBefore < wbnbToExecutor ? 0 : wbnbDebtBefore - wbnbToExecutor);
  }

  function testRevert_WhenDeleverage_MoreThanMaxBps_ShouldRevert() public {
    bytes[] memory manageBytes = new bytes[](1);
    manageBytes[0] = abi.encodeCall(PCSV3Executor01.deleverage, (L_USDTBNB_05_PCS1, 10001));
    vm.prank(manager);
    vm.expectRevert(abi.encodeWithSelector(PCSV3Executor01.PCSV3Executor01_InvalidParams.selector));
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);
  }

  function getVaultDebtAndDebtRatio() internal view returns (uint256 usdtDebt, uint256 wbnbDebt, uint256 debtRatio) {
    (, usdtDebt) = bank.getVaultDebt(L_USDTBNB_05_PCS1, address(usdt));
    (, wbnbDebt) = bank.getVaultDebt(L_USDTBNB_05_PCS1, address(wbnb));
    (uint256 vaultEquity, uint256 vaultDebt) = oracle.getEquityAndDebt(L_USDTBNB_05_PCS1, L_USDTBNB_05_PCS1_WORKER);
    debtRatio = vaultDebt * 1 ether / (vaultEquity + vaultDebt);
  }
}
