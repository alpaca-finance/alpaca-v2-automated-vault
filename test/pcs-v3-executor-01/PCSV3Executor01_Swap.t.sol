// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/Test.sol";

import { Bank } from "src/Bank.sol";
import { PCSV3Executor01, Executor } from "src/executors/PCSV3Executor01.sol";
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { PancakeV3VaultOracle } from "src/oracles/PancakeV3VaultOracle.sol";
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "test/fixtures/BscFixture.f.sol";

contract PCSV3Executor01SwapForkTest is BscFixture {
  address manager = 0x6EB9bC094CC57e56e91f3bec4BFfe7D9B1802e38;
  Bank bank = Bank(0xD0dfE9277B1DB02187557eAeD7e25F74eF2DE8f3);
  AutomatedVaultManager avManager = AutomatedVaultManager(0x2A9614504A12de8a85207199CdE1860269411F71);
  PCSV3Executor01 executor = PCSV3Executor01(0x7B33803D350293b271080ea78bE9CB0395d6d7E1);
  PancakeV3VaultOracle oracle = PancakeV3VaultOracle(0xa51b8f7dF8474111C6beA5eB2Fe60061C03FCEaf);
  ProxyAdmin proxyAdmin = ProxyAdmin(0xdAb7a2cca461F88eedBadF448C3957Ff20Cea1a7);
  address L_USDTBNB_05_PCS1 = 0xb08eE41e88A2820cd572B4f2DFc459549790F2D7;
  address L_USDTBNB_05_PCS1_WORKER = 0x463039266657602f60fc70De00553772f3cf4392;

  uint256 USDT_DEBT_AT_FORK_BLOCK = 1212716238577050315633979;
  uint256 WBNB_DEBT_AT_FORK_BLOCK = 713041660705218;

  constructor() BscFixture() {
    uint256 FORK_BLOCK_NUMBER = 31073975;
    vm.createSelectFork("bsc_mainnet", FORK_BLOCK_NUMBER);

    address newPCSV3Executor01 = address(new PCSV3Executor01());

    vm.startPrank(0xC44f82b07Ab3E691F826951a6E335E1bC1bB0B51);
    proxyAdmin.upgrade(ITransparentUpgradeableProxy(address(executor)), newPCSV3Executor01);
    // tolerance 1%
    avManager.setToleranceBps(L_USDTBNB_05_PCS1, 9900);
    vm.stopPrank();

    // harvest and accure interest
    PancakeV3Worker(L_USDTBNB_05_PCS1_WORKER).harvest();
    bank.accrueInterest(L_USDTBNB_05_PCS1);
  }

  function testRevert_WhenSwapWithInvalidtoken_ShouldRevert() external {
    bytes[] memory manageBytes = new bytes[](1);
    manageBytes[0] = abi.encodeCall(PCSV3Executor01.swap, (address(1), 10 ether, false));

    vm.prank(manager);
    vm.expectRevert(Executor.Executor_InvalidParams.selector);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);
  }

  function testRevert_WhenSwapWithMoreThanWorkerBalance_ShouldRevert() external {
    uint256 _wbnbWorkerBalance = wbnb.balanceOf(L_USDTBNB_05_PCS1_WORKER);
    bytes[] memory manageBytes = new bytes[](1);
    manageBytes[0] = abi.encodeCall(PCSV3Executor01.swap, (address(wbnb), _wbnbWorkerBalance + 100 ether, false));

    vm.prank(manager);
    vm.expectRevert();
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);
  }

  function testRevert_WhenExposureBeforeIsNegative_AfterSwap_ExposureBecomeMoreNegative_ShouldRevert() external {
    int256 exposure = oracle.getExposure(L_USDTBNB_05_PCS1, L_USDTBNB_05_PCS1_WORKER);
    assertLe(exposure, 0);
    bytes[] memory manageBytes = new bytes[](1);
    manageBytes[0] = abi.encodeCall(PCSV3Executor01.swap, (address(usdt), 10 ether, false));

    vm.prank(manager);
    vm.expectRevert(PCSV3Executor01.PCSV3Executor01_BadExposure.selector);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);
  }

  function testRevert_WhenExposureBeforeIsNegative_AfterSwap_ExposureBecomePositive_ShouldRevert() external {
    // repay most of usdt debt to change exposure
    uint256 _repayUSDTAmount = USDT_DEBT_AT_FORK_BLOCK - 1000 ether;
    deal(address(usdt), address(executor), _repayUSDTAmount);
    vm.mockCall(address(avManager), abi.encodeWithSignature("EXECUTOR_IN_SCOPE()"), abi.encode(address(executor)));

    vm.startPrank(address(executor));
    usdt.approve(address(bank), _repayUSDTAmount);
    bank.repayOnBehalfOf(L_USDTBNB_05_PCS1, address(usdt), _repayUSDTAmount);
    vm.stopPrank();

    int256 exposure = oracle.getExposure(L_USDTBNB_05_PCS1, L_USDTBNB_05_PCS1_WORKER);
    assertLt(exposure, 0);

    deal(address(wbnb), address(L_USDTBNB_05_PCS1_WORKER), 10 ether);
    bytes[] memory manageBytes = new bytes[](1);
    manageBytes[0] = abi.encodeCall(PCSV3Executor01.swap, (address(wbnb), 10 ether, false));

    vm.prank(manager);
    vm.expectRevert(PCSV3Executor01.PCSV3Executor01_BadExposure.selector);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);
  }

  function testRevert_WhenExposureBeforeIsPositive_AfterSwap_ExposureBecomeMorePositive_ShouldRevert() external {
    deal(address(usdt), address(L_USDTBNB_05_PCS1_WORKER), USDT_DEBT_AT_FORK_BLOCK + 100 ether);

    int256 exposure = oracle.getExposure(L_USDTBNB_05_PCS1, L_USDTBNB_05_PCS1_WORKER);
    assertGt(exposure, 0);
    bytes[] memory manageBytes = new bytes[](1);
    manageBytes[0] = abi.encodeCall(PCSV3Executor01.swap, (address(wbnb), 2 ether, false));

    vm.prank(manager);
    vm.expectRevert(PCSV3Executor01.PCSV3Executor01_BadExposure.selector);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);
  }

    function testCorrectness_WhenSkipExposureCheck_WhenExposureBecomeMorePositiveAfterSwap_ShouldWork() external {
    deal(address(usdt), address(L_USDTBNB_05_PCS1_WORKER), USDT_DEBT_AT_FORK_BLOCK + 100 ether);

    int256 exposure = oracle.getExposure(L_USDTBNB_05_PCS1, L_USDTBNB_05_PCS1_WORKER);
    assertGt(exposure, 0);
    bytes[] memory manageBytes = new bytes[](1);
    manageBytes[0] = abi.encodeCall(PCSV3Executor01.swap, (address(wbnb), 2 ether, false));

    vm.prank(executor.owner());
    executor.setSkipExposureChecks(L_USDTBNB_05_PCS1, true);

    vm.prank(manager);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);
    assertGt(oracle.getExposure(L_USDTBNB_05_PCS1, L_USDTBNB_05_PCS1_WORKER), exposure);
  }

  function testRevert_WhenExposureBeforeIsPositive_AfterSwap_ExposureBecomeNagative_ShouldRevert() external {
    deal(address(usdt), address(L_USDTBNB_05_PCS1_WORKER), USDT_DEBT_AT_FORK_BLOCK + 100 ether);

    int256 exposure = oracle.getExposure(L_USDTBNB_05_PCS1, L_USDTBNB_05_PCS1_WORKER);
    assertGt(exposure, 0);
    bytes[] memory manageBytes = new bytes[](1);
    manageBytes[0] = abi.encodeCall(PCSV3Executor01.swap, (address(usdt), 100 ether, false));

    vm.prank(manager);
    vm.expectRevert(PCSV3Executor01.PCSV3Executor01_BadExposure.selector);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);
  }

    function testCorrectness_WhenSkipExposureCheck_WhenExposureWentFromPositiveToNegative_ShouldWork() external {
    deal(address(usdt), address(L_USDTBNB_05_PCS1_WORKER), USDT_DEBT_AT_FORK_BLOCK + 100 ether);

    int256 exposure = oracle.getExposure(L_USDTBNB_05_PCS1, L_USDTBNB_05_PCS1_WORKER);
    assertGt(exposure, 0);
    bytes[] memory manageBytes = new bytes[](1);
    manageBytes[0] = abi.encodeCall(PCSV3Executor01.swap, (address(usdt), 100 ether, false));

    vm.prank(executor.owner());
    executor.setSkipExposureChecks(L_USDTBNB_05_PCS1, true);

    vm.prank(manager);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);
    assertLt(oracle.getExposure(L_USDTBNB_05_PCS1, L_USDTBNB_05_PCS1_WORKER), 0);
  }

  function testCorrectness_WhenExposureBeforeIsNegative_AfterSwap_ExposureGetCloserToZero_ShouldWork() external {
    int256 exposureBefore = oracle.getExposure(L_USDTBNB_05_PCS1, L_USDTBNB_05_PCS1_WORKER);
    assertLe(exposureBefore, 0);

    bytes[] memory manageBytes = new bytes[](1);
    manageBytes[0] = abi.encodeCall(PCSV3Executor01.swap, (address(wbnb), 10 ether, false));

    vm.prank(manager);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);

    int256 exposureAfter = oracle.getExposure(L_USDTBNB_05_PCS1, L_USDTBNB_05_PCS1_WORKER);
    assertGt(exposureAfter, exposureBefore);
  }

  function testRevert_WhenExposureBeforeIsNegative_AfterSwap_TooLittleReceivedTokenOut_ShouldRevert() external {
    // set very low slippage
    vm.prank(0xC44f82b07Ab3E691F826951a6E335E1bC1bB0B51);
    executor.setRepurchaseSlippageBps(1);

    bytes[] memory manageBytes = new bytes[](1);
    manageBytes[0] = abi.encodeCall(PCSV3Executor01.swap, (address(wbnb), 1000 ether, false));

    vm.prank(manager);
    vm.expectRevert(PCSV3Executor01.PCSV3Executor01_TooLittleReceived.selector);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);
  }
  function testRevert_WhenMinAmountIsLowerThanOracleSlippage_ShouldRevert() external {
    // set very low slippage
    vm.prank(0xC44f82b07Ab3E691F826951a6E335E1bC1bB0B51);
    executor.setRepurchaseSlippageBps(1);

    bytes[] memory manageBytes = new bytes[](1);
    manageBytes[0] = abi.encodeCall(PCSV3Executor01.swapWithMinAmountOut, (address(wbnb), 1000 ether, false, 0));

    vm.prank(manager);
    vm.expectRevert(PCSV3Executor01.PCSV3Executor01_TooLittleReceived.selector);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);
  }

  function testRevert_WhenMinAmountIsHigherThanOracleSlippage_ShouldRevert() external {
    // set very low slippage
    vm.prank(0xC44f82b07Ab3E691F826951a6E335E1bC1bB0B51);
    executor.setRepurchaseSlippageBps(1);

    bytes[] memory manageBytes = new bytes[](1);
    manageBytes[0] = abi.encodeCall(PCSV3Executor01.swapWithMinAmountOut, (address(wbnb), 1000 ether, false, 300000 ether));

    vm.prank(manager);
    vm.expectRevert(PCSV3Executor01.PCSV3Executor01_TooLittleReceived.selector);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);
  }
  

  function testCorrectness_WhenSwapAndRepay_TokenOutDebtShouldDecrease() external {
    (, uint256 usdtDebtBefore) = bank.getVaultDebt(L_USDTBNB_05_PCS1, address(usdt));

    // swap wbnb to usdt and repay
    bytes[] memory manageBytes = new bytes[](1);
    manageBytes[0] = abi.encodeCall(PCSV3Executor01.swap, (address(wbnb), 100 ether, true));

    vm.prank(manager);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);

    (, uint256 usdtDebtAfter) = bank.getVaultDebt(L_USDTBNB_05_PCS1, address(usdt));

    assertLt(usdtDebtAfter, usdtDebtBefore);
  }

  function testCorrrectness_WhenSwapWithOutRepay_TokenOutShouldBeSweepToWorker_ShouldWork() external {
    uint256 _usdtWorkerBalanceBefore = usdt.balanceOf(L_USDTBNB_05_PCS1_WORKER);

    // swap wbnb to usdt and repay
    bytes[] memory manageBytes = new bytes[](3);
    // transfer all usdt from worker to executor
    manageBytes[0] = abi.encodeCall(PCSV3Executor01.transferFromWorker, (address(usdt), _usdtWorkerBalanceBefore));
    // swap some wbnb to usdt without repay debt
    manageBytes[1] = abi.encodeCall(PCSV3Executor01.swap, (address(wbnb), 1 ether, false));
    // transfer usdt from worker to executor again with extra usdt
    manageBytes[2] =
      abi.encodeCall(PCSV3Executor01.transferFromWorker, (address(usdt), _usdtWorkerBalanceBefore + 100 ether));

    vm.prank(manager);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);
  }
}
