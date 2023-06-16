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
      worker: 0x9517b44741939776B13181a606dfEfb94a293b0a,
      vaultOracle: 0x09c32b9c17bbb20Ac884E5689A90b8087859c9F0,
      executor: 0x969A18e47256b35F54081a472D22e741C5AE607F,
      minimumDeposit: 1 ether,
      managementFeePerSec: 0,
      withdrawalFeeBps: 0,
      toleranceBps: 9500,
      maxLeverage: 8
    });

    vm.startBroadcast(deployerPrivateKey);

    address _vaultToken = AutomatedVaultManager(automatedVaultManager).openVault(_name, _symbol, vaultInfo);

    vm.stopBroadcast();

    console.log("newVaultToken : ", _vaultToken);
  }
}
