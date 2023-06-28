// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./BaseAutomatedVaultUnitTest.sol";

import { IERC20 } from "src/interfaces/IERC20.sol";

contract AutomatedVaultManagerSettersTest is BaseAutomatedVaultUnitTest {
  constructor() BaseAutomatedVaultUnitTest() { }

  function testRevert_SetVaultManager_NonOwnerIsCaller() public {
    address _vaultToken = makeAddr("vaultToken");
    address _manager = makeAddr("manager");

    vm.prank(USER_ALICE);
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.setVaultManager(_vaultToken, _manager, true);
  }
}

contract AutomatedVaultManagerSetAllowTokenTest is BaseAutomatedVaultUnitTest {
  function testRevert_SetAllowToken_NonOwnerIsCaller() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.setAllowToken(address(1), address(1234), true);
  }

  function testRevert_SetAllowToken_VaultNotOpened() public {
    vm.prank(DEPLOYER);
    vm.expectRevert(
      abi.encodeWithSelector(AutomatedVaultManager.AutomatedVaultManager_VaultNotExist.selector, address(1))
    );
    vaultManager.setAllowToken(address(1), address(1234), true);
  }
}

contract AutomatedVaultManagerSetVaultTokenImplementationTest is BaseAutomatedVaultUnitTest {
  function testRevert_SetVaultTokenImplementation_NonOwnerIsCaller() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.setVaultTokenImplementation(address(1234));
  }

  function testCorrectness_SetVaultTokenImplementation() public {
    address implementation = address(1234);
    vm.prank(DEPLOYER);
    vaultManager.setVaultTokenImplementation(implementation);
    assertEq(vaultManager.vaultTokenImplementation(), implementation);
  }
}

contract AutomatedVaultManagerSetToleranceBpsTest is BaseAutomatedVaultUnitTest {
  function testRevert_SetToleranceBps_NonOwnerIsCaller() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.setToleranceBps(address(1), 1);
  }

  function testRevert_SetToleranceBps_InvalidValue() public {
    vm.startPrank(DEPLOYER);
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_InvalidParams.selector);
    vaultManager.setToleranceBps(address(1), 1);
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_InvalidParams.selector);
    vaultManager.setToleranceBps(address(1), 10001);
  }

  function testCorrectness_SetToleranceBps() public {
    vm.startPrank(DEPLOYER);
    vaultManager.setToleranceBps(address(1), 9501);
    (,,,,,,, uint16 toleranceBps,) = vaultManager.vaultInfos(address(1));
    assertEq(toleranceBps, 9501);
    vaultManager.setToleranceBps(address(1), 9900);
    (,,,,,,, toleranceBps,) = vaultManager.vaultInfos(address(1));
    assertEq(toleranceBps, 9900);
    vaultManager.setToleranceBps(address(1), 10000);
    (,,,,,,, toleranceBps,) = vaultManager.vaultInfos(address(1));
    assertEq(toleranceBps, 10000);
  }
}

contract AutomatedVaultManagerSetMaxLeverageTest is BaseAutomatedVaultUnitTest {
  function testRevert_SetMaxLeverage_NonOwnerIsCaller() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.setMaxLeverage(address(1), 1);
  }

  function testRevert_SetMaxLeverage_InvalidValue() public {
    vm.startPrank(DEPLOYER);
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_InvalidParams.selector);
    vaultManager.setMaxLeverage(address(1), 0);
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_InvalidParams.selector);
    vaultManager.setMaxLeverage(address(1), 11);
  }

  function testCorrectness_SetMaxLeverage() public {
    vm.startPrank(DEPLOYER);
    vaultManager.setMaxLeverage(address(1), 1);
    (,,,,,,,, uint8 maxLeverage) = vaultManager.vaultInfos(address(1));
    assertEq(maxLeverage, 1);
    vaultManager.setMaxLeverage(address(1), 5);
    (,,,,,,,, maxLeverage) = vaultManager.vaultInfos(address(1));
    assertEq(maxLeverage, 5);
    vaultManager.setMaxLeverage(address(1), 10);
    (,,,,,,,, maxLeverage) = vaultManager.vaultInfos(address(1));
    assertEq(maxLeverage, 10);
  }
}

contract AutomatedVaultManagerSetMinimumDepositTest is BaseAutomatedVaultUnitTest {
  function testRevert_SetMinimumDeposit_NonOwnerIsCaller() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.setMinimumDeposit(address(1), 1);
  }

  function testRevert_SetMinimumDeposit_InvalidValue() public {
    vm.startPrank(DEPLOYER);
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_InvalidParams.selector);
    vaultManager.setMinimumDeposit(address(1), 0);
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_InvalidParams.selector);
    vaultManager.setMinimumDeposit(address(1), 1e18 - 1);
  }

  function testCorrectness_SetMinimumDeposit() public {
    vm.startPrank(DEPLOYER);
    vaultManager.setMinimumDeposit(address(1), 1e18);
    (,,, uint256 minimumDeposit,,,,,) = vaultManager.vaultInfos(address(1));
    assertEq(minimumDeposit, 1e18);
    vaultManager.setMinimumDeposit(address(1), 1e27);
    (,,, minimumDeposit,,,,,) = vaultManager.vaultInfos(address(1));
    assertEq(minimumDeposit, 1e27);
  }
}

contract AutomatedVaultManagerSetFeePerSecTest is BaseAutomatedVaultUnitTest {
  function testRevert_SetFeePerSec_NonOwnerIsCaller() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.setManagementFeePerSec(address(1), 1);
  }

  function testCorrectness_SetFeePerSec() public {
    vm.startPrank(DEPLOYER);
    vaultManager.setManagementFeePerSec(address(1), 10);
    (,,,,, uint256 managementFeePerSec,,,) = vaultManager.vaultInfos(address(1));
    assertEq(managementFeePerSec, 10);
    vaultManager.setManagementFeePerSec(address(1), 12);
    (,,,,, managementFeePerSec,,,) = vaultManager.vaultInfos(address(1));
    assertEq(managementFeePerSec, 12);
  }
}

contract AutomatedVaultManagerSetCapacityTest is BaseAutomatedVaultUnitTest {
  function testRevert_SetCapacity_NonOwnerIsCaller() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.setCapacity(address(1), 1);
  }

  function testCorrectness_SetCapacity() public {
    vm.startPrank(DEPLOYER);
    vaultManager.setCapacity(address(1), 10);
    (,,,, uint256 capacity,,,,) = vaultManager.vaultInfos(address(1));
    assertEq(capacity, 10);
    vaultManager.setCapacity(address(1), 0);
    (,,,, capacity,,,,) = vaultManager.vaultInfos(address(1));
    assertEq(capacity, 0);
  }
}

contract AutomatedVaultManagerSetEmergencyPausedTest is BaseAutomatedVaultUnitTest {
  // Deposit paused

  function testRevert_SetEmergencyDepositPaused_NonOwnerIsCaller() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.setEmergencyDepositPaused(new address[](1), true);
  }

  function testCorrectness_SetEmergencyDepositPaused_MultipleVaults() public {
    address _vaultToken1 = makeAddr("vaultToken1");
    address _vaultToken2 = makeAddr("vaultToken2");
    address[] memory _vaultTokens = new address[](2);
    _vaultTokens[0] = _vaultToken1;
    _vaultTokens[1] = _vaultToken2;

    // unset vaults should be false by default
    assertFalse(vaultManager.emergencyDepositPaused(_vaultToken1));
    assertFalse(vaultManager.emergencyDepositPaused(_vaultToken2));

    vm.startPrank(DEPLOYER);
    // should be true
    vaultManager.setEmergencyDepositPaused(_vaultTokens, true);
    assertTrue(vaultManager.emergencyDepositPaused(_vaultToken1));
    assertTrue(vaultManager.emergencyDepositPaused(_vaultToken2));

    // should be false
    vaultManager.setEmergencyDepositPaused(_vaultTokens, false);
    assertFalse(vaultManager.emergencyDepositPaused(_vaultToken1));
    assertFalse(vaultManager.emergencyDepositPaused(_vaultToken2));
    vm.stopPrank();
  }

  // Withdraw paused

  function testRevert_SetEmergencyWithdrawPaused_NonOwnerIsCaller() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.setEmergencyWithdrawPaused(new address[](1), true);
  }

  function testCorrectness_SetEmergencyWithdrawPaused_MultipleVaults() public {
    address _vaultToken1 = makeAddr("vaultToken1");
    address _vaultToken2 = makeAddr("vaultToken2");
    address[] memory _vaultTokens = new address[](2);
    _vaultTokens[0] = _vaultToken1;
    _vaultTokens[1] = _vaultToken2;

    // unset vaults should be false by default
    assertFalse(vaultManager.emergencyWithdrawPaused(_vaultToken1));
    assertFalse(vaultManager.emergencyWithdrawPaused(_vaultToken2));

    vm.startPrank(DEPLOYER);
    // should be true
    vaultManager.setEmergencyWithdrawPaused(_vaultTokens, true);
    assertTrue(vaultManager.emergencyWithdrawPaused(_vaultToken1));
    assertTrue(vaultManager.emergencyWithdrawPaused(_vaultToken2));

    // should be false
    vaultManager.setEmergencyWithdrawPaused(_vaultTokens, false);
    assertFalse(vaultManager.emergencyWithdrawPaused(_vaultToken1));
    assertFalse(vaultManager.emergencyWithdrawPaused(_vaultToken2));
    vm.stopPrank();
  }
}
