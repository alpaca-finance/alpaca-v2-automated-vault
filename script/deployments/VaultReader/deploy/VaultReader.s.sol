// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";
import { VaultReader } from "src/reader/VaultReader.sol";

contract VaultReaderScript is BaseScript {
  function run() public {
    vm.startBroadcast(deployerPrivateKey);

    address vaultReader = address(new VaultReader(automatedVaultManager, bank, pancakeV3VaultOracle));

    vm.stopBroadcast();

    _writeJson(vm.toString(vaultReader), ".automatedVault.vaultReader");
  }
}
