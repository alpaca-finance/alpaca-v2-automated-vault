// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "test/base/BaseTest.sol";

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";

contract AutomatedVaultUnitTest is BaseTest {
  AutomatedVaultManager vaultManager;

  function setUp() public override {
    super.setUp();

    vm.startPrank(DEPLOYER);
    vaultManager = AutomatedVaultManager(
      deployUpgradeable("AutomatedVaultManager", abi.encodeWithSelector(bytes4(keccak256("initialize()"))))
    );
    vm.stopPrank();
  }

  function testCorrectness_OpenVault_ShouldWork() public {
    address worker = makeAddr("worker");
    address depositExecutor = makeAddr("depositExecutor");

    vm.prank(DEPLOYER);
    address vaultToken = vaultManager.openVault(
      "test vault", "TV", AutomatedVaultManager.VaultInfo({ worker: worker, depositExecutor: depositExecutor })
    );

    (address vaultWorker, address vaultDepositExecutor) = vaultManager.vaultInfos(vaultToken);

    assertEq(vaultWorker, worker);
    assertEq(vaultDepositExecutor, depositExecutor);
  }

  function testRevert_NotOwnerOpenVault() public {
    address worker = makeAddr("worker");
    address depositExecutor = makeAddr("depositExecutor");

    vm.prank(ALICE);
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.openVault(
      "test vault", "TV", AutomatedVaultManager.VaultInfo({ worker: worker, depositExecutor: depositExecutor })
    );
  }

  // TODO: open vault sanity check test
}
