// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// dependencies
import "@forge-std/Vm.sol";
import "@forge-std/StdStorage.sol";
import { ProxyAdmin } from "@openzeppelin/proxy/transparent/ProxyAdmin.sol";

// contracts
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { Bank } from "src/Bank.sol";
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";

// interfaces
import { IERC20 } from "src/interfaces/IERC20.sol";

abstract contract TestHelpers {
  using stdStorage for StdStorage;

  Vm private constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

  StdStorage internal stdStore;
  ProxyAdmin internal proxyAdmin;

  constructor() {
    proxyAdmin = new ProxyAdmin();
  }

  function motherload(address token, address user, uint256 amount) internal {
    stdStore.target(token).sig(IERC20.balanceOf.selector).with_key(user).checked_write(amount);
  }

  function deployUpgradeable(string memory contractName, bytes memory initializer) internal returns (address) {
    // Deploy implementation contract
    bytes memory logicBytecode =
      abi.encodePacked(vm.getCode(string(abi.encodePacked("./out/", contractName, ".sol/", contractName, ".json"))));
    address logic;
    assembly {
      logic := create(0, add(logicBytecode, 0x20), mload(logicBytecode))
    }

    // Deploy proxy
    bytes memory proxyBytecode =
      abi.encodePacked(vm.getCode("./out/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json"));
    proxyBytecode = abi.encodePacked(proxyBytecode, abi.encode(logic, address(proxyAdmin), initializer));

    address proxy;
    assembly {
      proxy := create(0, add(proxyBytecode, 0x20), mload(proxyBytecode))
      if iszero(extcodesize(proxy)) { revert(0, 0) }
    }

    return proxy;
  }

  function deployAutomatedVaultManager() internal returns (AutomatedVaultManager) {
    return AutomatedVaultManager(
      deployUpgradeable("AutomatedVaultManager", abi.encodeWithSelector(bytes4(keccak256("initialize()"))))
    );
  }

  function deployBank(address moneyMarket, address vaultManager) internal returns (Bank) {
    return Bank(
      deployUpgradeable(
        "Bank", abi.encodeWithSelector(bytes4(keccak256("initialize(address,address)")), moneyMarket, vaultManager)
      )
    );
  }

  function deployPancakeV3Worker(PancakeV3Worker.ConstructorParams memory params) internal returns (PancakeV3Worker) {
    return PancakeV3Worker(
      deployUpgradeable(
        "PancakeV3Worker",
        abi.encodeWithSelector(
          bytes4(keccak256("initialize((address,address,address,address,address,address,int24,int24,uint16))")),
          address(params.positionManager),
          address(params.pool),
          address(params.router),
          address(params.masterChef),
          address(params.zapV3),
          params.performanceFeeBucket,
          params.tickLower,
          params.tickUpper,
          params.performanceFeeBps
        )
      )
    );
  }
}
