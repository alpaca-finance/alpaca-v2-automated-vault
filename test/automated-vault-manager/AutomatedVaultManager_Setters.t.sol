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
