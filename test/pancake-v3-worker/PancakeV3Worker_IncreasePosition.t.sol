// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// fixtures
import "test/fixtures/PancakeV3WorkerFixture.f.sol";

import { LibTickMath } from "src/libraries/LibTickMath.sol";
import { LibLiquidityAmounts } from "src/libraries/LibLiquidityAmounts.sol";

contract PancakeV3WorkerIncreasePositionTest is PancakeV3WorkerFixture {
  using stdStorage for StdStorage;

  constructor() PancakeV3WorkerFixture() {}

  function testRevert_OpenPosition_NotExecutorInScope() public {
    vm.prank(address(1234));
    vm.expectRevert(PancakeV3Worker.PancakeV3Worker_Unauthorized.selector);
    worker.openPosition(TICK_LOWER, TICK_UPPER, 1 ether, 1 ether);
  }

  function testRevert_OpenPosition_PositionExist() public {
    // overwrite `nftTokenId` storage to some address
    stdstore.target(address(worker)).sig("nftTokenId()").checked_write(address(1234));

    vm.prank(IN_SCOPE_EXECUTOR);
    vm.expectRevert(PancakeV3Worker.PancakeV3Worker_PositionExist.selector);
    worker.openPosition(TICK_LOWER, TICK_UPPER, 1 ether, 1 ether);
  }

  // TODO: out of range
  function testCorrectness_OpenPosition_InRange() public {
    assertEq(worker.nftTokenId(), 0);

    uint256 amountIn0 = 1 ether;
    uint256 amountIn1 = 1 ether;

    deal(address(token0), address(worker), amountIn0);
    deal(address(token1), address(worker), amountIn1);

    uint256 _amount0Before = token0.balanceOf(address(worker));
    uint256 _amount1Before = token1.balanceOf(address(worker));

    vm.prank(IN_SCOPE_EXECUTOR);
    worker.openPosition(TICK_LOWER, TICK_UPPER, amountIn0, amountIn1);
    
    uint256 _tokenId = PancakeV3Worker(worker).nftTokenId();
    (uint160 _poolSqrtPriceX96, , , , , , ) = ICommonV3Pool(PancakeV3Worker(worker).pool()).slot0();
    (, , , , , int24 _tickLower, int24 _tickUpper, uint128 _liquidity, , , , ) = PancakeV3Worker(worker)
      .nftPositionManager()
      .positions(_tokenId);

    (uint256 _token0Farmed, uint256 _token1Farmed) = LibLiquidityAmounts.getAmountsForLiquidity(
      _poolSqrtPriceX96,
      LibTickMath.getSqrtRatioAtTick(_tickLower),
      LibTickMath.getSqrtRatioAtTick(_tickUpper),
      _liquidity
    );
    // Worker assertions
    // - token0 remain less than DUST
    // - token1 remain less than DUST
    // - state `nftTokenId` should be set
    // - state `posTickLower` should be set to specified tick
    // - state `posTickUpper` should be set to specified tick
    assertApproxEqAbs(token0.balanceOf(address(worker)), (_amount0Before - _token0Farmed), 1);
    assertApproxEqAbs(token1.balanceOf(address(worker)), (_amount1Before - _token1Farmed), 1);
    assertEq(worker.nftTokenId(), 46528);
    assertEq(worker.posTickLower(), TICK_LOWER);
    assertEq(worker.posTickUpper(), TICK_UPPER);

    // External assertions
    // - nft should be staked with masterChef
    // - staked nft should have tick same as worker
    IPancakeV3MasterChef.UserPositionInfo memory userInfo = pancakeV3MasterChef.userPositionInfos(worker.nftTokenId());
    assertEq(userInfo.user, address(worker));
    assertEq(userInfo.tickLower, worker.posTickLower());
    assertEq(userInfo.tickUpper, worker.posTickUpper());
  }

  function testRevert_IncreasePosition_NotExecutorInScope() public {
    vm.prank(address(1234));
    vm.expectRevert(PancakeV3Worker.PancakeV3Worker_Unauthorized.selector);
    worker.increasePosition(1 ether, 1 ether);
  }

  function testRevert_IncreasePosition_PositionNotExist() public {
    // overwrite `nftTokenId` storage to zero
    stdstore.target(address(worker)).sig("nftTokenId()").checked_write(address(0));

    vm.prank(IN_SCOPE_EXECUTOR);
    vm.expectRevert(PancakeV3Worker.PancakeV3Worker_PositionNotExist.selector);
    worker.increasePosition(1 ether, 1 ether);
  }

  // TODO: out of range
  function testCorrectness_IncreasePosition_InRange() public {
    // Open position
    deal(address(token0), address(worker), 1 ether);
    deal(address(token1), address(worker), 1 ether);
    vm.prank(IN_SCOPE_EXECUTOR);
    worker.openPosition(TICK_LOWER, TICK_UPPER, 1 ether, 1 ether);

    uint256 amountIn0 = 1 ether;
    uint256 amountIn1 = 1 ether;

    IPancakeV3MasterChef.UserPositionInfo memory userInfoBefore = pancakeV3MasterChef.userPositionInfos(
      worker.nftTokenId()
    );

    deal(address(token0), address(worker), amountIn0);
    deal(address(token1), address(worker), amountIn1);
    vm.prank(IN_SCOPE_EXECUTOR);
    worker.increasePosition(amountIn0, amountIn1);

    // External assertions
    // - staked position liquidity should be increased
    IPancakeV3MasterChef.UserPositionInfo memory userInfoAfter = pancakeV3MasterChef.userPositionInfos(
      worker.nftTokenId()
    );
    assertGt(userInfoAfter.liquidity, userInfoBefore.liquidity);

    // Worker invariants
    // - state `nftTokenId` should remain the same
    // - state `posTickLower` should remain the same
    // - state `posTickUpper` should remain the same
    assertEq(worker.nftTokenId(), 46528);
    assertEq(worker.posTickLower(), TICK_LOWER);
    assertEq(worker.posTickUpper(), TICK_UPPER);
  }
}
