// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { ERC20 } from "@solmate/tokens/ERC20.sol";

import "test/base/BaseForkTest.sol";

import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";

import { IAutomatedVaultManager } from "src/interfaces/IAutomatedVaultManager.sol";
import { IPancakeV3Router } from "src/interfaces/pancake-v3/IPancakeV3Router.sol";

import { Tasks } from "src/libraries/Constants.sol";

abstract contract BasePancakeV3WorkerUnitForkTest is BaseForkTest {
  int24 internal constant TICK_LOWER = -58000;
  int24 internal constant TICK_UPPER = -57750;
  uint16 internal constant PERFORMANCE_FEE_BPS = 1_000;

  PancakeV3Worker worker;
  ERC20 token0;
  ERC20 token1;
  uint24 poolFee;
  // TODO: mock vault manager?
  IAutomatedVaultManager vaultManager = IAutomatedVaultManager(address(1));
  address IN_SCOPE_EXECUTOR = makeAddr("IN_SCOPE_EXECUTOR");

  function setUp() public virtual override {
    super.setUp();

    vm.createSelectFork("bsc_mainnet", 27_515_914);

    vm.prank(DEPLOYER);
    worker = deployPancakeV3Worker(
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

  struct CommonV3ImportantPositionInfo {
    address token0;
    address token1;
    int24 tickLower;
    int24 tickUpper;
    uint128 liquidity;
    uint128 tokensOwed0;
    uint128 tokensOwed1;
  }

  function _getImportantPositionInfo(uint256 tokenId) internal view returns (CommonV3ImportantPositionInfo memory info) {
    (,, info.token0, info.token1,, info.tickLower, info.tickUpper, info.liquidity,,, info.tokensOwed0, info.tokensOwed1)
    = pancakeV3PositionManager.positions(tokenId);
  }

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
}
