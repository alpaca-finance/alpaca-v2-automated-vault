// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

contract SetAllowTokenScript is BaseScript {
  function run() public {
    address _vaultToken = address(0);
    address _token = usdt;
    bool _isAllow = true;

    vm.startBroadcast(deployerPrivateKey);

    AutomatedVaultManager(automatedVaultManager).setAllowToken(_vaultToken, _token, _isAllow);

    vm.stopBroadcast();
  }
}
