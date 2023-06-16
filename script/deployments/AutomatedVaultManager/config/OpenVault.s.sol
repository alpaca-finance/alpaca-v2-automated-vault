// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployAutomatedVaultManagerScript is BaseScript {
  function run() public {
    string memory _name = "Market Neutral USDT-BNB-500 PCS1";
    string memory _symbol = "N-USDT-BNB-500-PCS1";

    AutomatedVaultManager.VaultInfo memory vaultInfo = AutomatedVaultManager.VaultInfo({
      worker: address(0),
      vaultOracle: address(0),
      executor: address(0),
      minimumDeposit: 0,
      managementFeePerSec: 0,
      withdrawalFeeBps: 0,
      toleranceBps: 100,
      maxLeverage: 8
    });

    vm.startBroadcast(deployerPrivateKey);

    AutomatedVaultManager(automatedVaultManager).openVault(_name, _symbol, vaultInfo);

    vm.stopBroadcast();
  }
}
