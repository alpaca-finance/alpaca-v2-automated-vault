// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { Executor } from "src/executors/Executor.sol";
import { PCSV3Executor01 } from "src/executors/PCSV3Executor01.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployPCSV3Executor01Script is BaseScript {
  function run() public {
    vm.startBroadcast(deployerPrivateKey);

    // Deploy implementation
    address executorImplementation = address(new PCSV3Executor01());

    // Deploy proxy
    bytes memory initializerData = abi.encodeWithSelector(Executor.initialize.selector, automatedVaultManager, bank);
    address executorProxy = address(
      new TransparentUpgradeableProxy(
      executorImplementation,
      proxyAdmin,
      initializerData
      )
    );

    vm.stopBroadcast();

    _writeJson(vm.toString(executorImplementation), ".automatedVault.pancake-v3-vault.executor01.implementation");
    _writeJson(vm.toString(executorProxy), ".automatedVault.pancake-v3-vault.executor01.proxy");
  }
}
