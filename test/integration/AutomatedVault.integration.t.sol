// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "test/base/BaseTest.sol";

import { IAutomatedVaultManager } from "src/interfaces/IAutomatedVaultManager.sol";

contract AutomatedVaultIntegrationTest is BaseTest {
  IAutomatedVaultManager vaultManager;

  function setUp() public override {
    vm.startPrank(DEPLOYER);
    vaultManager = IAutomatedVaultManager(
      deployUpgradeable("AutomatedVaultManager", abi.encodeWithSelector(bytes4(keccak256("initialize()"))))
    );
    vm.stopPrank();
  }
}
