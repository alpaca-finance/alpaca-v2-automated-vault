// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../fixtures/PancakeV3WorkerExecutorBankIntegrationFixture.f.sol";

// Contract under test
// - PCSV3Executor01
// - PancakeV3Worker

// Scenario
// current tick = -57864, tick spacing = 10
// 1) vault manager partially open position
// 2) vault manager partially increase position

contract TC04 is PancakeV3WorkerExecutorBankIntegrationFixture {
  constructor() PancakeV3WorkerExecutorBankIntegrationFixture() { }

  function _swapExactInput(address tokenIn_, address tokenOut_, uint24 fee_, uint256 swapAmount) internal {
    deal(tokenIn_, address(this), swapAmount);
    // Approve router to spend token1
    IERC20(tokenIn_).approve(address(pancakeV3Router), swapAmount);
    // Swap
    pancakeV3Router.exactInputSingle(
      IPancakeV3Router.ExactInputSingleParams({
        tokenIn: tokenIn_,
        tokenOut: tokenOut_,
        fee: fee_,
        recipient: address(this),
        amountIn: swapAmount,
        amountOutMinimum: 0,
        sqrtPriceLimitX96: 0
      })
    );
  }

  function test_TC04_Partial_Open_IncreasePosition() public {
    vm.startPrank(mockVaultManager);

    // Mock vault manager executor in scope
    vm.mockCall(mockVaultManager, abi.encodeWithSignature("EXECUTOR_IN_SCOPE()"), abi.encode(address(executor)));
    // Set worker and vault token for executor
    executor.setExecutionScope(address(workerUSDTWBNB), address(mockVaultUSDTWBNBToken));

    deal(address(usdt), address(workerUSDTWBNB), 335 ether);
    deal(address(wbnb), address(workerUSDTWBNB), 1 ether);

    //
    // Step 1: vault manager partially open position
    //
    executor.openPosition(-58860, -56860, 134 ether, 0.4 ether);
    // Assertions
    // - worker balance is used by open position amount
    assertApproxEqAbs(usdt.balanceOf(address(workerUSDTWBNB)), 201 ether, 1000);
    assertApproxEqAbs(wbnb.balanceOf(address(workerUSDTWBNB)), 0.6 ether, 1000);
    // - when close position should get approx starting amount
    uint256 snapshot = vm.snapshot();
    executor.closePosition();
    assertApproxEqRel(usdt.balanceOf(address(workerUSDTWBNB)), 335 ether, 1e16);
    assertApproxEqRel(wbnb.balanceOf(address(workerUSDTWBNB)), 1 ether, 1e16);
    vm.revertTo(snapshot);

    //
    // Step 2: vault manager partially increase position
    //
    executor.increasePosition(134 ether, 0.4 ether);
    // Assertions
    // - worker balance is used by increase position amount
    assertApproxEqAbs(usdt.balanceOf(address(workerUSDTWBNB)), 67 ether, 1000);
    assertApproxEqAbs(wbnb.balanceOf(address(workerUSDTWBNB)), 0.2 ether, 1000);
    // - when close position should get approx starting amount
    snapshot = vm.snapshot();
    executor.closePosition();
    assertApproxEqRel(usdt.balanceOf(address(workerUSDTWBNB)), 335 ether, 1e16);
    assertApproxEqRel(wbnb.balanceOf(address(workerUSDTWBNB)), 1 ether, 1e16);
    vm.revertTo(snapshot);
  }
}
