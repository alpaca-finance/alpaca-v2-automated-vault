// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "test/base/BaseTest.sol";

// TODO: migrate to new test structure
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";

contract AutomatedVaultUnitTest is BaseTest {
  AutomatedVaultManager vaultManager;

  function setUp() public override {
    super.setUp();

    vm.startPrank(DEPLOYER);
    vaultManager = deployAutomatedVaultManager();
    vm.stopPrank();
  }

  function testCorrectness_OpenVault_ShouldWork() public {
    address worker = makeAddr("worker");
    address vaultOracle = makeAddr("vaultOracle");
    address depositExecutor = makeAddr("depositExecutor");

    vm.prank(DEPLOYER);
    address vaultToken = vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.VaultInfo({ worker: worker, vaultOracle: vaultOracle, depositExecutor: depositExecutor })
    );

    (address vaultWorker, address vaultWorkerOracle, address vaultDepositExecutor) = vaultManager.vaultInfos(vaultToken);

    assertEq(vaultWorker, worker);
    assertEq(vaultWorkerOracle, vaultOracle);
    assertEq(vaultDepositExecutor, depositExecutor);
  }

  function testRevert_NotOwnerOpenVault() public {
    address worker = makeAddr("worker");
    address vaultOracle = makeAddr("vaultOracle");
    address depositExecutor = makeAddr("depositExecutor");

    vm.prank(ALICE);
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.VaultInfo({ worker: worker, vaultOracle: vaultOracle, depositExecutor: depositExecutor })
    );
  }

  // TODO: open vault sanity check test
}
