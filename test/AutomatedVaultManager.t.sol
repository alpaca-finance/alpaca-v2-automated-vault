// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";

// fixtures
import "test/fixtures/ProtocolActorFixture.f.sol";

// helpers
import { DeployHelper } from "test/helpers/DeployHelper.sol";

contract AutomatedVaultUnitTest is ProtocolActorFixture {
  AutomatedVaultManager vaultManager;

  constructor() ProtocolActorFixture() {
    vm.startPrank(DEPLOYER);
    vaultManager = AutomatedVaultManager(
      DeployHelper.deployUpgradeable("AutomatedVaultManager", abi.encodeWithSignature("initialize()"))
    );
    vm.stopPrank();
  }

  function testCorrectness_OpenVault() public {
    address worker = makeAddr("worker");
    address vaultOracle = makeAddr("vaultOracle");
    address depositExecutor = makeAddr("depositExecutor");
    address updateExecutor = makeAddr("updateExecutor");

    vm.prank(DEPLOYER);
    address vaultToken = vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.VaultInfo({
        worker: worker,
        vaultOracle: vaultOracle,
        depositExecutor: depositExecutor,
        withdrawExecutor: address(0),
        updateExecutor: updateExecutor
      })
    );

    (address vaultWorker, address vaultWorkerOracle, address vaultDepositExecutor,, address vaultUpdateExecutor) =
      vaultManager.vaultInfos(vaultToken);

    assertEq(vaultWorker, worker);
    assertEq(vaultWorkerOracle, vaultOracle);
    assertEq(vaultDepositExecutor, depositExecutor);
    assertEq(vaultUpdateExecutor, updateExecutor);
  }

  function testRevert_OpenVault_NonOwnerIsCaller() public {
    address worker = makeAddr("worker");
    address vaultOracle = makeAddr("vaultOracle");
    address depositExecutor = makeAddr("depositExecutor");
    address updateExecutor = makeAddr("updateExecutor");

    vm.prank(USER_ALICE);
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.VaultInfo({
        worker: worker,
        vaultOracle: vaultOracle,
        depositExecutor: depositExecutor,
        withdrawExecutor: address(0),
        updateExecutor: updateExecutor
      })
    );
  }

  // TODO: open vault sanity check test
}
