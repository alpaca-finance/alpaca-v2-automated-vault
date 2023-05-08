// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "test/base/BaseForkTest.sol";

import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";

import { IAutomatedVaultManager } from "src/interfaces/IAutomatedVaultManager.sol";

contract PancakeV3WorkerUnitForkTest is BaseForkTest {
  int24 internal constant TICK_LOWER = -58000;
  int24 internal constant TICK_UPPER = -57750;
  uint16 internal constant PERFORMANCE_FEE_BPS = 1_000;

  PancakeV3Worker worker;

  function setUp() public override {
    super.setUp();

    vm.startPrank(DEPLOYER);
    worker = deployPancakeV3Worker(
      PancakeV3Worker.ConstructorParams({
        vaultManager: IAutomatedVaultManager(address(0)), // TODO: mock vault manager
        positionManager: pancakeV3PositionManager,
        pool: pancakeV3WBNBUSDTPool,
        router: pancakeV3Router,
        masterChef: pancakeV3MasterChef,
        zapV3: zapV3,
        performanceFeeBucket: PERFORMANCE_FEE_BUCKET,
        tickLower: TICK_LOWER,
        tickUpper: TICK_UPPER,
        performanceFeeBps: PERFORMANCE_FEE_BPS
      })
    );
    vm.stopPrank();
  }

  function testtest() public { }
}
