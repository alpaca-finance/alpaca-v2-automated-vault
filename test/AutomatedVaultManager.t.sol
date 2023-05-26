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
    uint16 toleranceBps = 100;
    uint8 maxLeverage = 10;

    vm.prank(DEPLOYER);
    address vaultToken = vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.VaultInfo({
        worker: worker,
        vaultOracle: vaultOracle,
        depositExecutor: depositExecutor,
        updateExecutor: updateExecutor,
        toleranceBps: toleranceBps,
        maxLeverage: maxLeverage
      })
    );

    (
      address vaultWorker,
      address vaultWorkerOracle,
      address vaultDepositExecutor,
      address vaultUpdateExecutor,
      uint16 vaultToleranceBps,
      uint8 vaultMaxLeverage
    ) = vaultManager.vaultInfos(vaultToken);

    assertEq(vaultWorker, worker);
    assertEq(vaultWorkerOracle, vaultOracle);
    assertEq(vaultDepositExecutor, depositExecutor);
    assertEq(vaultUpdateExecutor, updateExecutor);
    assertEq(vaultToleranceBps, toleranceBps);
    assertEq(vaultMaxLeverage, maxLeverage);
  }

  function testRevert_OpenVault_NonOwnerIsCaller() public {
    address _worker = makeAddr("worker");
    address _vaultOracle = makeAddr("vaultOracle");
    address _depositExecutor = makeAddr("depositExecutor");
    address _updateExecutor = makeAddr("updateExecutor");

    vm.prank(USER_ALICE);
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.VaultInfo({
        worker: _worker,
        vaultOracle: _vaultOracle,
        depositExecutor: _depositExecutor,
        updateExecutor: _updateExecutor,
        toleranceBps: 10,
        maxLeverage: 10
      })
    );
  }

  function testRevert_SetVaultManager_NonOwnerIsCaller() public {
    address _vaultToken = makeAddr("vaultToken");
    address _manager = makeAddr("manager");

    vm.prank(USER_ALICE);
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.setVaultManagers(_vaultToken, _manager, true);
  }

  // TODO: open vault sanity check test
}
