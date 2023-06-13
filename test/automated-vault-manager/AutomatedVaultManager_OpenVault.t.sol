// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./BaseAutomatedVaultUnitTest.sol";

import { IERC20 } from "src/interfaces/IERC20.sol";

// TODO: open vault sanity check test
contract AutomatedVaultManagerOpenVaultTest is BaseAutomatedVaultUnitTest {
  address worker = makeAddr("worker");
  address vaultOracle = makeAddr("vaultOracle");
  address executor = makeAddr("executor");

  constructor() BaseAutomatedVaultUnitTest() {
    // Mock for sanity check
    vm.mockCall(vaultOracle, abi.encodeWithSignature("maxPriceAge()"), abi.encode(1));
    vm.mockCall(executor, abi.encodeWithSignature("vaultManager()"), abi.encode(address(vaultManager)));
  }

  function testCorrectness_OpenVault() public {
    uint256 minimumDeposit = 100 ether;
    uint16 toleranceBps = 9900;
    uint8 maxLeverage = 10;

    vm.prank(DEPLOYER);
    address vaultToken = vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.VaultInfo({
        worker: worker,
        vaultOracle: vaultOracle,
        executor: executor,
        minimumDeposit: minimumDeposit,
        toleranceBps: toleranceBps,
        maxLeverage: maxLeverage
      })
    );

    // Assert vault manager
    (
      address vaultWorker,
      address vaultWorkerOracle,
      address vaultExecutor,
      uint256 vaultMinimumDeposit,
      uint16 vaultToleranceBps,
      uint8 vaultMaxLeverage
    ) = vaultManager.vaultInfos(vaultToken);
    assertEq(vaultWorker, worker);
    assertEq(vaultWorkerOracle, vaultOracle);
    assertEq(vaultExecutor, executor);
    assertEq(vaultToleranceBps, toleranceBps);
    assertEq(vaultMaxLeverage, maxLeverage);
    assertEq(vaultMinimumDeposit, minimumDeposit);
    assertEq(vaultManager.workerExisted(worker), true);

    // Assert vault token
    assertEq(AutomatedVaultERC20(vaultToken).vaultManager(), address(vaultManager));
  }

  function testRevert_OpenVault_NonOwnerIsCaller() public {
    vm.prank(USER_ALICE);
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.VaultInfo({
        worker: worker,
        vaultOracle: vaultOracle,
        executor: executor,
        minimumDeposit: 100 ether,
        toleranceBps: 9900,
        maxLeverage: 10
      })
    );
  }

  function testRevert_OpenVault_InvalidParams() public {
    vm.startPrank(DEPLOYER);
    // Invalid minumumDeposit
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_InvalidParams.selector);
    vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.VaultInfo({
        worker: worker,
        vaultOracle: vaultOracle,
        executor: executor,
        minimumDeposit: 0.1 ether,
        toleranceBps: 9900,
        maxLeverage: 10
      })
    );
    // Invalid toleranceBps
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_InvalidParams.selector);
    vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.VaultInfo({
        worker: worker,
        vaultOracle: vaultOracle,
        executor: executor,
        minimumDeposit: 1 ether,
        toleranceBps: 1,
        maxLeverage: 10
      })
    );
    // Invalid maxLeverage
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_InvalidParams.selector);
    vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.VaultInfo({
        worker: worker,
        vaultOracle: vaultOracle,
        executor: executor,
        minimumDeposit: 1 ether,
        toleranceBps: 9900,
        maxLeverage: 11
      })
    );
    // Invalid vaultOracle
    vm.clearMockedCalls();
    vm.mockCall(executor, abi.encodeWithSignature("vaultManager()"), abi.encode(address(vaultManager)));
    vm.expectRevert();
    vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.VaultInfo({
        worker: worker,
        vaultOracle: vaultOracle,
        executor: executor,
        minimumDeposit: 1 ether,
        toleranceBps: 9900,
        maxLeverage: 10
      })
    );
    // Executor mismatch
    vm.clearMockedCalls();
    vm.mockCall(vaultOracle, abi.encodeWithSignature("maxPriceAge()"), abi.encode(1));
    vm.mockCall(executor, abi.encodeWithSignature("vaultManager()"), abi.encode(address(1234)));
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_InvalidParams.selector);
    vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.VaultInfo({
        worker: worker,
        vaultOracle: vaultOracle,
        executor: executor,
        minimumDeposit: 1 ether,
        toleranceBps: 9900,
        maxLeverage: 10
      })
    );
    // Invalid executor
    vm.clearMockedCalls();
    vm.mockCall(vaultOracle, abi.encodeWithSignature("maxPriceAge()"), abi.encode(1));
    vm.expectRevert();
    vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.VaultInfo({
        worker: worker,
        vaultOracle: vaultOracle,
        executor: executor,
        minimumDeposit: 1 ether,
        toleranceBps: 9900,
        maxLeverage: 10
      })
    );

    vm.mockCall(vaultOracle, abi.encodeWithSignature("maxPriceAge()"), abi.encode(1));
    vm.mockCall(executor, abi.encodeWithSignature("vaultManager()"), abi.encode(address(vaultManager)));
    // Open valid vault
    vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.VaultInfo({
        worker: worker,
        vaultOracle: vaultOracle,
        executor: executor,
        minimumDeposit: 1 ether,
        toleranceBps: 9900,
        maxLeverage: 10
      })
    );
    // Worker already exist
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_InvalidParams.selector);
    vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.VaultInfo({
        worker: worker,
        vaultOracle: vaultOracle,
        executor: executor,
        minimumDeposit: 1 ether,
        toleranceBps: 9900,
        maxLeverage: 10
      })
    );
  }
}
