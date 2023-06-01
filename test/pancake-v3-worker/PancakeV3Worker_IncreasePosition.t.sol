// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// fixtures
import "test/fixtures/PancakeV3WorkerFixture.f.sol";

contract PancakeV3WorkerIncreasePositionTest is PancakeV3WorkerFixture {
  using stdStorage for StdStorage;

  constructor() PancakeV3WorkerFixture() { }

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

    uint256 token0Before = token0.balanceOf(IN_SCOPE_EXECUTOR);
    uint256 token1Before = token1.balanceOf(IN_SCOPE_EXECUTOR);

    vm.prank(IN_SCOPE_EXECUTOR);
    worker.openPosition(TICK_LOWER, TICK_UPPER, amountIn0, amountIn1);

    // Executor assertions
    // - token0 should be deducted by specified amount
    // - token1 should be deducted by specified amount
    assertEq(token0Before - token0.balanceOf(IN_SCOPE_EXECUTOR), amountIn0);
    assertEq(token1Before - token1.balanceOf(IN_SCOPE_EXECUTOR), amountIn1);

    // Worker assertions
    // - token0 remain less than DUST
    // - token1 remain less than DUST
    // - state `nftTokenId` should be set
    // - state `posTickLower` should be set to specified tick
    // - state `posTickUpper` should be set to specified tick
    assertLt(token0.balanceOf(address(worker)), DUST);
    assertLt(token1.balanceOf(address(worker)), DUST);
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
    vm.prank(IN_SCOPE_EXECUTOR);
    worker.openPosition(TICK_LOWER, TICK_UPPER, 1 ether, 1 ether);

    uint256 amountIn0 = 1 ether;
    uint256 amountIn1 = 1 ether;

    uint256 token0Before = token0.balanceOf(IN_SCOPE_EXECUTOR);
    uint256 token1Before = token1.balanceOf(IN_SCOPE_EXECUTOR);
    IPancakeV3MasterChef.UserPositionInfo memory userInfoBefore =
      pancakeV3MasterChef.userPositionInfos(worker.nftTokenId());

    vm.prank(IN_SCOPE_EXECUTOR);
    worker.increasePosition(amountIn0, amountIn1);

    // Executor assertions
    // - token0 should be deducted by specified amount
    // - token1 should be deducted by specified amount
    assertEq(token0Before - token0.balanceOf(IN_SCOPE_EXECUTOR), amountIn0);
    assertEq(token1Before - token1.balanceOf(IN_SCOPE_EXECUTOR), amountIn1);

    // External assertions
    // - staked position liquidity should be increased
    IPancakeV3MasterChef.UserPositionInfo memory userInfoAfter =
      pancakeV3MasterChef.userPositionInfos(worker.nftTokenId());
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
