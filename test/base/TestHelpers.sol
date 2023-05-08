// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/Vm.sol";
import "@forge-std/StdStorage.sol";
import { ProxyAdmin } from "@openzeppelin/proxy/transparent/ProxyAdmin.sol";

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
}
