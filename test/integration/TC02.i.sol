// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../fixtures/PancakeV3WorkerExecutorBankIntegrationFixture.f.sol";

// Contract under test
// - Bank
// - PCSV3Executor01
// - PancakeV3Worker

// Scope
// - onUpdate
// - openPosition
// - borrow
// - repay

// Scenario
// current tick = -57864, tick spacing = 10
// 1) vault manager open in range position with borrowed + undeployed funds
// trading fee accrue
// 2) vault manager call onUpdate
// CAKE reward, accrue
// 3) vault manager call onUpdate
// borrowing interest accrue
// 4) vault manager call onUpdate
// 5) vault manager withdraw

contract TC02 is PancakeV3WorkerExecutorBankIntegrationFixture {
  constructor() PancakeV3WorkerExecutorBankIntegrationFixture() { }

  function _swapExactInput(address tokenIn_, address tokenOut_, uint24 fee_, uint256 swapAmount)
    internal
    returns (uint256 amountOut)
  {
    deal(tokenIn_, address(this), swapAmount);
    // Approve router to spend token1
    IERC20(tokenIn_).approve(address(pancakeV3Router), swapAmount);
    // Swap
    amountOut = pancakeV3Router.exactInputSingle(
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

  function test_TC02_OnUpdate_CollectTradingFee_HarvestCake_AccrueBorrowingInterest() public {
    vm.startPrank(mockVaultManager);

    // Mock vault manager executor in scope
    vm.mockCall(mockVaultManager, abi.encodeWithSignature("EXECUTOR_IN_SCOPE()"), abi.encode(address(executor)));
    // Set worker and vault token for executor
    executor.setExecutionScope(address(workerUSDTWBNB), address(mockVaultUSDTWBNBToken));

    //
    // Step 1: vault manager open in range position with borrowed + undeployed funds
    //
    // note that equity must be greater than debt
    deal(address(usdt), address(workerUSDTWBNB), 150_000 ether);
    deal(address(wbnb), address(mockMoneyMarket), 333 ether);
    executor.borrow(address(wbnb), 333 ether);
    executor.transferToWorker(address(wbnb), 333 ether);
    executor.openPosition(-57870, -57860, 150_000 ether, 333 ether);
    // Mimic vault manager minting shares when deposit
    deal(address(mockVaultUSDTWBNBToken), address(this), 1 ether, true);

    // Wash trade to generate trading fee while maintain in range (swap amountOut from first swap back)
    changePrank(address(this));
    _swapExactInput(address(usdt), address(wbnb), 500, _swapExactInput(address(wbnb), address(usdt), 500, 10_000 ether));
    changePrank(mockVaultManager);

    //
    // Step 2: vault manager call onUpdate
    //
    uint256 usdtBefore = usdt.balanceOf(address(workerUSDTWBNB));
    uint256 wbnbBefore = wbnb.balanceOf(address(workerUSDTWBNB));
    executor.onUpdate(address(mockVaultUSDTWBNBToken), workerUSDTWBNB);
    // Assertions
    // - trading fees should be collected
    // - worker balance should increase by trading fees
    (,,,,,,,,,, uint128 token0Owed, uint128 token1Owed) =
      pancakeV3PositionManager.positions(workerUSDTWBNB.nftTokenId());
    assertEq(token0Owed, 0);
    assertEq(token1Owed, 0);
    assertGt(usdt.balanceOf(address(workerUSDTWBNB)), usdtBefore);
    assertGt(wbnb.balanceOf(address(workerUSDTWBNB)), wbnbBefore);

    // Time passed, CAKE reward accrued
    skip(100_000);

    //
    // Step 3: vault manager call onUpdate
    //
    usdtBefore = usdt.balanceOf(address(workerUSDTWBNB));
    executor.onUpdate(address(mockVaultUSDTWBNBToken), workerUSDTWBNB);
    // Assertions
    // - CAKE reward should be harvested
    // - worker usdt should increase due to harvested reward being swapped to usdt (current tick is closer to tick lower)
    IPancakeV3MasterChef.UserPositionInfo memory userInfo =
      pancakeV3MasterChef.userPositionInfos(workerUSDTWBNB.nftTokenId());
    assertEq(userInfo.reward, 0);
    assertGt(usdt.balanceOf(address(workerUSDTWBNB)), usdtBefore);

    // Money market accure borrowing interest
    mockMoneyMarket.pretendAccrueInterest(address(bank), address(wbnb), 1 ether);

    //
    // Step 4: vault manager call onUpdate
    //
    executor.onUpdate(address(mockVaultUSDTWBNBToken), workerUSDTWBNB);

    //
    // Step 5: vault manager withdraw
    //
    usdtBefore = usdt.balanceOf(mockVaultManager);
    wbnbBefore = wbnb.balanceOf(mockVaultManager);
    executor.onWithdraw(workerUSDTWBNB, address(mockVaultUSDTWBNBToken), 1 ether);
    // Assertions
    // - executor balance is 0 (forward all to vault manager)
    // - worker balance is 0 (withdraw 100%)
    // - vault manager balance increase
    // - all debt repaid
    assertEq(usdt.balanceOf(address(executor)), 0);
    assertEq(wbnb.balanceOf(address(executor)), 0);
    assertEq(usdt.balanceOf(address(workerUSDTWBNB)), 0);
    assertEq(wbnb.balanceOf(address(workerUSDTWBNB)), 0);
    assertGt(usdt.balanceOf(address(mockVaultManager)), usdtBefore);
    assertGt(wbnb.balanceOf(address(mockVaultManager)), wbnbBefore);
    (, uint256 usdtDebt) = bank.getVaultDebt(address(mockVaultUSDTWBNBToken), address(usdt));
    assertEq(usdtDebt, 0);
    (, uint256 wbnbDebt) = bank.getVaultDebt(address(mockVaultUSDTWBNBToken), address(wbnb));
    assertEq(wbnbDebt, 0);
  }
}