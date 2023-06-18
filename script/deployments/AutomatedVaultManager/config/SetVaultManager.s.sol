// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

contract SetVaultManagerScript is BaseScript {
  function run() public {
    address _vaultToken = 0x130A4791cC36c3aaD8d4282404D5D7976C1E9246;
    address _manager = 0x6EB9bC094CC57e56e91f3bec4BFfe7D9B1802e38;
    bool _isManagerOk = true;

    vm.startBroadcast(deployerPrivateKey);

    AutomatedVaultManager(automatedVaultManager).setVaultManager(_vaultToken, _manager, _isManagerOk);

    vm.stopBroadcast();
  }
}
