// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// fixtures
import "test/fixtures/PancakeV3WorkerFixture.f.sol";

contract PancakeV3WorkerHarvestTest is PancakeV3WorkerFixture {
  using stdStorage for StdStorage;

  constructor() PancakeV3WorkerFixture() { }

  function _swapExactInput(address tokenIn_, address tokenOut_, uint24 fee_, uint256 swapAmount) internal {
    deal(tokenIn_, address(this), swapAmount);
    // Approve router to spend token1
    ERC20(tokenIn_).approve(address(pancakeV3Router), swapAmount);
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

  function testCorrectness_WorkerHasNoUnClaimTrandingFeeAndReward_WhenHarvest_ShouldWork() external {
    uint256 token0Before = token0.balanceOf(address(worker));
    uint256 token1Before = token1.balanceOf(address(worker));
    uint256 cakeBefore = cake.balanceOf(address(worker));

    worker.harvest();

    assertEq(token0Before, token0.balanceOf(address(worker)));
    assertEq(token1Before, token1.balanceOf(address(worker)));
    assertEq(cakeBefore, cake.balanceOf(address(worker)));
  }

  function testCorrectness_WorkerHasUnClaimTrandingFeeAndReward_WhenHarvest_ShouldWork() external {
    // Increase position by 10_000 TKN0 and 1 TKN1
    deal(address(token0), address(worker), 10_000 ether);
    deal(address(token1), address(worker), 1 ether);
    // Assume worker somehow has cake left to test swap
    deal(address(cake), address(worker), 1 ether);
    vm.prank(IN_SCOPE_EXECUTOR);
    worker.openPosition(TICK_LOWER, TICK_UPPER, 10_000 ether, 1 ether);

    // Assuming some trades happened
    // pool current Tick at -57856
    _swapExactInput(address(token1), address(token0), poolFee, 500 ether);
    _swapExactInput(address(token0), address(token1), poolFee, 500 ether);

    // move block timestamp to bypass same blocktimeStamp check
    vm.warp(block.timestamp + 100);

    // snapshot evm state and get the actual reward of the worker for easy calculation
    uint256 snapShotId = vm.snapshot();
    vm.startPrank(address(worker));

    (uint256 _token0CollectAmount, uint256 _token1CollectAmount) = pancakeV3MasterChef.collect(
      IPancakeV3MasterChef.CollectParams({
        tokenId: worker.nftTokenId(),
        recipient: address(worker),
        amount0Max: type(uint128).max,
        amount1Max: type(uint128).max
      })
    );

    uint256 _token0ToBucket = _token0CollectAmount * TRADING_PERFORMANCE_FEE_BPS / 10_000;
    uint256 _token1ToBucket = _token1CollectAmount * TRADING_PERFORMANCE_FEE_BPS / 10_000;
    uint256 _harvestAmount = pancakeV3MasterChef.harvest(worker.nftTokenId(), address(worker));
    uint256 _cakeToBucket = _harvestAmount * REWARD_PERFORMANCE_FEE_BPS / 10_000;
    uint256 _swapAmount = _harvestAmount - _cakeToBucket;

    cake.approve(address(pancakeV3Router), _swapAmount);
    uint256 _token1SwapAmountOut = pancakeV3Router.exactInput(
      IPancakeV3Router.ExactInputParams({
        path: worker.cakeToTokenPath(address(token1)),
        recipient: address(worker),
        amountIn: _swapAmount,
        amountOutMinimum: 0
      })
    );
    vm.stopPrank();
    vm.revertTo(snapShotId);

    // call actual harvest
    worker.harvest();

    // Assert PERFORMANCE_FEE_BUCK Balance
    // PERFORMANCE_FEE_BUCK get PERFORMANCE_FEE_BPS% from the total reward
    assertEq(token0.balanceOf(PERFORMANCE_FEE_BUCKET), _token0ToBucket);
    assertEq(token1.balanceOf(PERFORMANCE_FEE_BUCKET), _token1ToBucket);
    assertEq(cake.balanceOf(PERFORMANCE_FEE_BUCKET), _cakeToBucket);

    // Assert worker Balance
    assertEq(token0.balanceOf(address(worker)), _token0CollectAmount - _token0ToBucket);
    assertEq(token1.balanceOf(address(worker)), _token1CollectAmount + _token1SwapAmountOut - _token1ToBucket);
    // Invariant: Cake after harvest should remain the same
    assertEq(cake.balanceOf(address(worker)), 1 ether);
  }
}
