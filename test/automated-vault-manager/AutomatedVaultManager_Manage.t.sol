// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./BaseAutomatedVaultUnitTest.sol";

import { IERC20 } from "src/interfaces/IERC20.sol";

contract AutomatedVaultManagerManagerTest is BaseAutomatedVaultUnitTest {
  constructor() BaseAutomatedVaultUnitTest() { }

  function testCorrectness_ManagingVaultResultInHealthyState_ShouldWork() external {
    address vaultToken = _openDefaultVault();

    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), new bytes[](0));
  }

  function testRevert_WhenNonManagerCallManage_ShouldRevert() external {
    address vaultToken = _openDefaultVault();

    bytes[] memory _params = new bytes[](1);
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_Unauthorized.selector);
    vaultManager.manage(address(vaultToken), _params);
  }
}
