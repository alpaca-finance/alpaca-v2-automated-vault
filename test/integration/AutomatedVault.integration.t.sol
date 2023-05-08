// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "test/base/BaseForkTest.sol";

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { Bank } from "src/Bank.sol";
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { SimpleV3DepositExecutor } from "src/executors/SimpleV3DepositExecutor.sol";

contract AutomatedVaultIntegrationForkTest is BaseForkTest {
  int24 internal constant TICK_LOWER = -58000;
  int24 internal constant TICK_UPPER = -57750;
  uint16 internal constant PERFORMANCE_FEE_BPS = 1_000;

  AutomatedVaultManager vaultManager;
  Bank bank;
  PancakeV3Worker pcsV3Worker;
  SimpleV3DepositExecutor depositExecutor;
  address vaultToken;

  function setUp() public override {
    super.setUp();

    vm.startPrank(DEPLOYER);

    vaultManager = deployAutomatedVaultManager();
    bank = deployBank(address(0), address(vaultManager));
    pcsV3Worker = deployPancakeV3Worker(
      PancakeV3Worker.ConstructorParams({
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
    depositExecutor = new SimpleV3DepositExecutor(address(pcsV3Worker), address(bank));
    vaultToken = vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.VaultInfo({ worker: address(pcsV3Worker), depositExecutor: address(depositExecutor) })
    );

    vm.stopPrank();
  }

  function testCorrectness_Yay() public { }
}
