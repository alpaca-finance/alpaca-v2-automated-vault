// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { ERC20 } from "@solmate/tokens/ERC20.sol";

import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";

import { IAutomatedVaultManager } from "src/interfaces/IAutomatedVaultManager.sol";
import { IPancakeV3MasterChef } from "src/interfaces/pancake-v3/IPancakeV3MasterChef.sol";

// fixtures
import "test/fixtures/BscFixture.f.sol";
import "test/fixtures/ProtocolActorFixture.f.sol";

// helpers
import { DeployHelper } from "test/helpers/DeployHelper.sol";

contract PancakeV3WorkerIncreasePositionTest is BscFixture, ProtocolActorFixture {
  using stdStorage for StdStorage;

  int24 internal constant TICK_LOWER = -58000;
  int24 internal constant TICK_UPPER = -57750;
  uint16 internal constant PERFORMANCE_FEE_BPS = 1_000;
  uint256 internal constant DUST = 0.000000001 ether;

  PancakeV3Worker worker;
  ERC20 token0;
  ERC20 token1;
  uint24 poolFee;
  IAutomatedVaultManager vaultManager = IAutomatedVaultManager(address(1));
  address IN_SCOPE_EXECUTOR = makeAddr("IN_SCOPE_EXECUTOR");

  constructor() BscFixture() ProtocolActorFixture() {
    vm.createSelectFork("bsc_mainnet", BscFixture.FORK_BLOCK_NUMBER_1);

    vm.prank(DEPLOYER);
    worker = PancakeV3Worker(
      DeployHelper.deployUpgradeable(
        "PancakeV3Worker",
        abi.encodeWithSelector(
          PancakeV3Worker.initialize.selector,
          PancakeV3Worker.ConstructorParams({
            vaultManager: vaultManager,
            positionManager: pancakeV3PositionManager,
            pool: pancakeV3USDTWBNBPool,
            router: pancakeV3Router,
            masterChef: pancakeV3MasterChef,
            zapV3: zapV3,
            performanceFeeBucket: PERFORMANCE_FEE_BUCKET,
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            performanceFeeBps: PERFORMANCE_FEE_BPS
          })
        )
      )
    );

    token0 = worker.token0();
    token1 = worker.token1();
    poolFee = worker.poolFee();

    vm.mockCall(
      address(vaultManager),
      abi.encodeWithSelector(IAutomatedVaultManager.EXECUTOR_IN_SCOPE.selector),
      abi.encode(IN_SCOPE_EXECUTOR)
    );

    vm.startPrank(IN_SCOPE_EXECUTOR);
    token0.approve(address(worker), type(uint256).max);
    token1.approve(address(worker), type(uint256).max);
    vm.stopPrank();

    deal(address(token0), IN_SCOPE_EXECUTOR, 100_000 ether);
    deal(address(token1), IN_SCOPE_EXECUTOR, 100_000 ether);
  }

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

  // TODO: fuzz to get coverage of in and out of range
  function testCorrectness_OpenPosition() public {
    assertEq(worker.nftTokenId(), 0);

    uint256 amountIn0 = 1 ether;
    uint256 amountIn1 = 1 ether;

    uint256 token0Before = token0.balanceOf(IN_SCOPE_EXECUTOR);
    uint256 token1Before = token1.balanceOf(IN_SCOPE_EXECUTOR);

    vm.prank(IN_SCOPE_EXECUTOR);
    worker.openPosition(TICK_LOWER, TICK_UPPER, amountIn0, amountIn1);

    // Assertions
    // - executor's token0 should be deducted by specified amount
    // - executor's token1 should be deducted by specified amount
    // - `nftTokenId` should be set
    // - `posTickLower` should be set to specified tick
    // - `posTickUpper` should be set to specified tick
    // - nft should be staked with masterChef
    // - staked nft should have tick same as worker

    assertEq(token0Before - token0.balanceOf(IN_SCOPE_EXECUTOR), amountIn0);
    assertEq(token1Before - token1.balanceOf(IN_SCOPE_EXECUTOR), amountIn1);
    assertEq(worker.nftTokenId(), 46528);
    assertEq(worker.posTickLower(), TICK_LOWER);
    assertEq(worker.posTickUpper(), TICK_UPPER);
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

  // TODO: fuzz to get coverage of in and out of range
  function testCorrectness_IncreasePosition() public {
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

    // Assertions
    // - executor's token0 should be deducted by specified amount
    // - executor's token1 should be deducted by specified amount
    // - staked position liquidity should be increased

    assertEq(token0Before - token0.balanceOf(IN_SCOPE_EXECUTOR), amountIn0);
    assertEq(token1Before - token1.balanceOf(IN_SCOPE_EXECUTOR), amountIn1);
    IPancakeV3MasterChef.UserPositionInfo memory userInfoAfter =
      pancakeV3MasterChef.userPositionInfos(worker.nftTokenId());
    assertGt(userInfoAfter.liquidity, userInfoBefore.liquidity);

    // Invariants
    // - `nftTokenId` should remain the same
    // - `posTickLower` should remain the same
    // - `posTickUpper` should remain the same

    assertEq(worker.nftTokenId(), 46528);
    assertEq(worker.posTickLower(), TICK_LOWER);
    assertEq(worker.posTickUpper(), TICK_UPPER);
  }
}
