// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployAutomatedVaultManagerScript is BaseScript {
  function run() public {
    vm.startBroadcast(deployerPrivateKey);

    // Deploy implementation
    address automatedVaultManagerImplementation = address(new AutomatedVaultManager());

    // Deploy proxy
    bytes memory initializerData =
      abi.encodeWithSelector(AutomatedVaultManager.initialize.selector, automatedVaultERC20Implementation);
    address automatedVaultManagerProxy = address(
      new TransparentUpgradeableProxy(
      automatedVaultManagerImplementation,
      proxyAdmin,
      initializerData
      )
    );

    vm.stopBroadcast();

    _writeJson(vm.toString(automatedVaultManagerImplementation), ".automatedVault.automatedVaultManager.implementation");
    _writeJson(vm.toString(automatedVaultManagerProxy), ".automatedVault.automatedVaultManager.proxy");
  }
}
