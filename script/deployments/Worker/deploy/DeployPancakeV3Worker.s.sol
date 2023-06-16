// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployPancakeV3WorkerScript is BaseScript {
  function run() public {
    vm.startBroadcast(deployerPrivateKey);

    _deployWorker(pancakeV3USDTWBNB500Pool, 1_000);

    vm.stopBroadcast();
  }

  function _deployWorker(address pool, uint16 performanceFeeBps) internal {
    // Deploy implementation
    address workerImplementation = address(new PancakeV3Worker());

    // Deploy proxy
    bytes memory initializerData = abi.encodeWithSelector(
      PancakeV3Worker.initialize.selector,
      PancakeV3Worker.ConstructorParams({
        vaultManager: automatedVaultManager,
        positionManager: pancakeV3PositionManager,
        pool: pool,
        router: pancakeV3Router,
        masterChef: pancakeV3MasterChef,
        zapV3: zapV3,
        performanceFeeBucket: performanceFeeBucket,
        performanceFeeBps: performanceFeeBps
      })
    );
    address workerProxy = address(
      new TransparentUpgradeableProxy(
      workerImplementation,
      proxyAdmin,
      initializerData
      )
    );

    // TODO: write to json array
    // _writeJson(vm.toString(workerImplementation), ".automatedVault.pancake-v3-vault.workers.implementation");
    // _writeJson(vm.toString(workerProxy), ".automatedVault.pancake-v3-vault.workers.proxy");
  }
}
