// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./BaseAutomatedVaultUnitTest.sol";

import { IERC20 } from "src/interfaces/IERC20.sol";

contract AutomatedVaultManagerManageTest is BaseAutomatedVaultUnitTest {
  address vaultToken;

  constructor() BaseAutomatedVaultUnitTest() {
    vaultToken = _openDefaultVault();
  }

  function testRevert_WhenNonManagerCallManage_ShouldRevert() external {
    vm.prank(address(1234));
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_Unauthorized.selector);
    vaultManager.manage(address(vaultToken), new bytes[](1));
  }

  function testFuzzRevert_WhenManageCauseTooMuchEquityLoss(uint16 tolerance, uint256 equityBefore, uint256 equityAfter)
    public
  {
    tolerance = uint16(bound(tolerance, 1, 10000)); // can't allow 100% loss
    equityBefore = bound(equityBefore, 1, 1e30);
    equityAfter = bound(equityAfter, 0, equityBefore * tolerance / 10000);
    if (equityAfter > 0) equityAfter -= 1; // prevent equal case

    // tolerate up to 1% equity loss
    vaultToken = _openVault(DEFAULT_MINIMUM_DEPOSIT, tolerance, DEFAULT_MAX_LEVERAGE);

    mockVaultOracleAndExecutor.setGetEquityAndDebtResult({
      _equityBefore: equityBefore,
      _debtBefore: 0,
      _equityAfter: equityAfter,
      _debtAfter: 0
    });

    vm.prank(MANAGER);
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_TooMuchEquityLoss.selector);
    vaultManager.manage(address(vaultToken), new bytes[](0));
  }

  function testRevert_WhenManageCauseTooMuchLeverage() public {
    // max 10x leverage
    vaultToken = _openVault(DEFAULT_MINIMUM_DEPOSIT, DEFAULT_TOLERANCE_BPS, 10);

    // 10x leverage with 100 equity allow up to 900 debt
    // 901 should revert
    mockVaultOracleAndExecutor.setGetEquityAndDebtResult({
      _equityBefore: 100,
      _debtBefore: 0,
      _equityAfter: 100,
      _debtAfter: 901
    });

    vm.prank(MANAGER);
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_TooMuchLeverage.selector);
    vaultManager.manage(address(vaultToken), new bytes[](0));
  }

  function testCorrectness_ManagingVaultResultInHealthyState_ShouldWork() external {
    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), new bytes[](0));

    // Invariant: EXECUTOR_IN_SCOPE == address(0)
    assertEq(vaultManager.EXECUTOR_IN_SCOPE(), address(0));
  }
}
