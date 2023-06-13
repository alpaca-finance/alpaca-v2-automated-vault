// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./BaseAutomatedVaultUnitTest.sol";

import { IERC20 } from "src/interfaces/IERC20.sol";

// TODO: open vault sanity check test
contract AutomatedVaultManagerOpenVaultTest is BaseAutomatedVaultUnitTest {
  constructor() BaseAutomatedVaultUnitTest() { }

  function testCorrectness_OpenVault() public {
    address worker = makeAddr("worker");
    address vaultOracle = makeAddr("vaultOracle");
    address executor = makeAddr("executor");
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

    // Assert vault token
    assertEq(AutomatedVaultERC20(vaultToken).vaultManager(), address(vaultManager));
  }

  function testRevert_OpenVault_NonOwnerIsCaller() public {
    address _worker = makeAddr("worker");
    address _vaultOracle = makeAddr("vaultOracle");
    address _executor = makeAddr("executor");

    vm.prank(USER_ALICE);
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.VaultInfo({
        worker: _worker,
        vaultOracle: _vaultOracle,
        executor: _executor,
        minimumDeposit: 100 ether,
        toleranceBps: 9900,
        maxLeverage: 10
      })
    );
  }
}
