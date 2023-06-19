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
      worker: 0x969A18e47256b35F54081a472D22e741C5AE607F,
      vaultOracle: 0x42f3A6c5e555a83F00208340b60aE2643CE90a62,
      executor: 0xd8BD07eDFd276AA23EB4B6806C904728B4C7DCb3,
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
