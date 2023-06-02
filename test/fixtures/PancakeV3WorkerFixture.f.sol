// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { ERC20 } from "@solmate/tokens/ERC20.sol";

import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";

import { IAutomatedVaultManager } from "src/interfaces/IAutomatedVaultManager.sol";

// fixtures
import "test/fixtures/BscFixture.f.sol";
import "test/fixtures/ProtocolActorFixture.f.sol";

// helpers
import { DeployHelper } from "test/helpers/DeployHelper.sol";

contract PancakeV3WorkerFixture is BscFixture, ProtocolActorFixture {
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
}
