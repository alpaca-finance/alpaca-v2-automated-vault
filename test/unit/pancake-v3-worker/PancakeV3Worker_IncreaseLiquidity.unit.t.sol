// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./BasePancakeV3Worker.unit.sol";

contract PancakeV3Worker_IncreaseLiquidity_UnitForkTest is BasePancakeV3WorkerUnitForkTest {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_IncreaseLiquidity_InRange_Subsequently() public {
    // Assert
    // - Worker's tokenId must be 0
    assertEq(worker.nftTokenId(), 0, "tokenId must be 0");

    // Increase position by 10_000 TKN0 and 1 TKN1
    vm.prank(IN_SCOPE_EXECUTOR);
    worker.doWork(Tasks.INCREASE, abi.encode(10_000 ether, 1 ether));

    // Asserts:
    // - token0 and token1 must left in worker less than DUST
    // - tokenId must be 46528
    assertLt(token0.balanceOf(address(worker)), DUST, "token0 must left in worker less than DUST");
    assertLt(token1.balanceOf(address(worker)), DUST, "token1 must left in worker less than DUST");
    assertEq(worker.nftTokenId(), 46528, "tokenId must be 46528");

    CommonV3ImportantPositionInfo memory positionInfo = _getImportantPositionInfo(46528);
    assertEq(positionInfo.tickLower, TICK_LOWER, "tickLower must be TICK_LOWER");
    assertEq(positionInfo.tickUpper, TICK_UPPER, "tickUpper must be TICK_UPPER");
    assertEq(positionInfo.liquidity, 45904151499858308508910, "liquidity must be 45904151499858308508910");
    assertEq(positionInfo.tokensOwed0, 0, "tokensOwed0 must be 0");
    assertEq(positionInfo.tokensOwed1, 0, "tokensOwed1 must be 0");

    // Increase position by 10_000 TKN0 and 25_000 TKN1 again
    vm.prank(IN_SCOPE_EXECUTOR);
    worker.doWork(Tasks.INCREASE, abi.encode(10_000 ether, 25_000 ether));

    // Assert:
    // - token0 and token1 must left in worker less than DUST
    // - Worker's tokenId must be 46528
    // - Worker's position's liquidity must be 20_000 TKN0 and 50_000 TKN1
    assertLt(token0.balanceOf(address(worker)), DUST, "token0 must left in worker less than DUST");
    assertLt(token1.balanceOf(address(worker)), DUST, "token1 must left in worker less than DUST");
    assertEq(worker.nftTokenId(), 46528, "tokenId must be 25902");

    positionInfo = _getImportantPositionInfo(46528);
    assertEq(positionInfo.tickLower, TICK_LOWER, "tickLower must be TICK_LOWER");
    assertEq(positionInfo.tickUpper, TICK_UPPER, "tickUpper must be TICK_UPPER");
    assertEq(positionInfo.liquidity, 36235370516829017460459509, "liquidity must be 36235370516829017460459509");
    assertEq(positionInfo.tokensOwed0, 0, "tokensOwed0 must be 0");
    assertEq(positionInfo.tokensOwed1, 3439773883040434, "tokensOwed1 must be 3439773883040434");
  }

  function testCorrectness_IncreaseLiquidity_OutOfRange_CurTickMoreThanTickUpper_AfterSwappedStillOutOfRange() public {
    // Swap so that pool's current tick goes beyond TICK_UPPER
    _swapExactInput(address(token1), address(token0), poolFee, 5_500 ether);

    // Asserts:
    // - pool's current tick goes beyond TICK_UPPER
    // - pool's position should be out of range
    (, int24 currTick,,,,,) = pancakeV3USDTWBNBPool.slot0();
    assertGt(currTick, TICK_UPPER, "currTick must be more than TICK_UPPER");
    assertFalse(TICK_LOWER <= currTick && currTick <= TICK_UPPER, "should out of range");

    // Increase position by 10_000 USDT and 10 WBNB
    vm.prank(IN_SCOPE_EXECUTOR);
    worker.doWork(Tasks.INCREASE, abi.encode(10_000 ether, 10 ether));

    // Assert:
    // - token0 and token1 must NOT left in worker
    // - Worker's tokenId must be 46528
    assertEq(token0.balanceOf(address(worker)), 0, "worker's token0 must be 0");
    assertEq(token1.balanceOf(address(worker)), 0, "worker's token1 must be 0");
    assertEq(worker.nftTokenId(), 46528, "tokenId must be 46528");
  }

  function testCorrectness_IncreaseLiquidity_OutOfRange_CurTickMoreThanTickUpper_AfterSwappedInRange() public {
    // Swap so that pool's current tick goes beyond TICK_UPPER
    _swapExactInput(address(token1), address(token0), poolFee, 5_500 ether);

    // Asserts:
    // - pool's current tick goes beyond TICK_UPPER
    // - pool's position should be out of range
    (, int24 currTick,,,,,) = pancakeV3USDTWBNBPool.slot0();
    assertGt(currTick, TICK_UPPER, "currTick must be more than TICK_UPPER");
    assertFalse(TICK_LOWER <= currTick && currTick <= TICK_UPPER, "should out of range");

    // Increase position by 10_000 USDT and 0 WBNB
    vm.prank(IN_SCOPE_EXECUTOR);
    worker.doWork(Tasks.INCREASE, abi.encode(10_000 ether, 0));

    // Assert:
    // - token0 and token1 must less than DUST
    // - Worker's tokenId must be 46528
    assertLt(token0.balanceOf(address(worker)), DUST, "worker's token0 must be less than DUST");
    assertLt(token1.balanceOf(address(worker)), DUST, "worker's token1 must be less than DUST");
    assertEq(worker.nftTokenId(), 46528, "tokenId must be 46528");
  }

  function testCorrectness_IncreaseLiquidity_OutOfRange_CurTickLessThanTickLower_AfterSwappedStillOutOfRange() public {
    // Swap so that pool's current tick goes below TICK_LOWER
    _swapExactInput(address(token0), address(token1), poolFee, 2_000_000 ether);

    // Asserts:
    // - pool's current tick goes below TICK_LOWER
    // - pool's position should be out of range
    (, int24 currTick,,,,,) = pancakeV3USDTWBNBPool.slot0();
    assertTrue(currTick < TICK_LOWER, "currTick must be less than TICK_LOWER");
    assertFalse(TICK_LOWER <= currTick && currTick <= TICK_UPPER, "should out of range");

    // Increase position by 10_000 USDT and 1 WBNB
    vm.prank(IN_SCOPE_EXECUTOR);
    worker.doWork(Tasks.INCREASE, abi.encode(10_000 ether, 10 ether));

    // Assert:
    // - token0 and token1 must NOT left in worker
    // - Worker's tokenId must be 46528
    assertEq(token0.balanceOf(address(worker)), 0, "worker's token0 must be 0");
    assertEq(token1.balanceOf(address(worker)), 0, "worker's token1 must be 0");
    assertEq(worker.nftTokenId(), 46528, "tokenId must be 46528");
  }

  function testCorrectness_IncreaseLiquidity_OutOfRange_CurTickLessThanTickLower_AfterSwappedInRange() public {
    // Swap so that pool's current tick goes below TICK_LOWER
    _swapExactInput(address(token0), address(token1), poolFee, 2_000_000 ether);

    // Asserts:
    // - pool's current tick goes below TICK_LOWER
    // - pool's position should be out of range
    (, int24 currTick,,,,,) = pancakeV3USDTWBNBPool.slot0();
    assertTrue(currTick < TICK_LOWER, "currTick must be less than TICK_LOWER");
    assertFalse(TICK_LOWER <= currTick && currTick <= TICK_UPPER, "should out of range");

    // Increase position by 0 USDT and 300 WBNB
    vm.prank(IN_SCOPE_EXECUTOR);
    worker.doWork(Tasks.INCREASE, abi.encode(0 ether, 300 ether));

    // Assert:
    // - token0 and token1 must NOT left in worker
    // - Worker's tokenId must be 46528
    assertLt(token0.balanceOf(address(worker)), DUST, "worker's token0 must less than DUST");
    assertLt(token1.balanceOf(address(worker)), DUST, "worker's token1 must less than DUST");
    assertEq(worker.nftTokenId(), 46528, "tokenId must be 46528");
  }

  function testRevert_NotExecutorInScopeCallDoWork() public {
    // call from some address that is not in scope
    vm.prank(ALICE);
    vm.expectRevert(PancakeV3Worker.PancakeV3Worker_Unauthorized.selector);
    worker.doWork(Tasks.INCREASE, abi.encode());
  }

  function testRevert_CallDoWorkWithInvalidTask() public {
    vm.prank(IN_SCOPE_EXECUTOR);
    vm.expectRevert(PancakeV3Worker.PancakeV3Worker_InvalidTask.selector);
    // use address.call as workaround to call worker with invalid task enum
    (bool _success,) = address(worker).call(
      abi.encodeWithSelector(PancakeV3Worker.doWork.selector, address(this), uint8(255), abi.encode())
    );
    _success; // to silence solc warning
  }
}
