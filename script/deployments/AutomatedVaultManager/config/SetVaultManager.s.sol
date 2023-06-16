// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

contract SetVaultManagerScript is BaseScript {
  function run() public {
    address _vaultToken = address(0);
    address _manager = address(0);
    bool _isManagerOk = true;

    vm.startBroadcast(deployerPrivateKey);

    AutomatedVaultManager(automatedVaultManager).setVaultManager(_vaultToken, _manager, _isManagerOk);

    vm.stopBroadcast();
  }
}
