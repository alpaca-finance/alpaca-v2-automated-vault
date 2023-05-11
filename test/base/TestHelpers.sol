// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// dependencies
import { Vm } from "@forge-std/Vm.sol";
import { StdStorage, stdStorage } from "@forge-std/StdStorage.sol";
import { StdCheats } from "@forge-std/StdCheats.sol";
import { ProxyAdmin } from "@openzeppelin/proxy/transparent/ProxyAdmin.sol";

// contracts
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { Bank } from "src/Bank.sol";
import { CommonV3LiquidityOracle } from "src/CommonV3LiquidityOracle.sol";
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { MockMoneyMarket } from "test/mocks/MockMoneyMarket.sol";

// interfaces
import { IERC20 } from "src/interfaces/IERC20.sol";

abstract contract TestHelpers is StdCheats {
  using stdStorage for StdStorage;

  Vm private constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

  StdStorage internal stdStore;
  ProxyAdmin internal proxyAdmin;

  constructor() {
    proxyAdmin = new ProxyAdmin();
  }

  function normalizeToE18(uint256 amount, uint256 decimals) internal pure returns (uint256) {
    return amount * (10 ** (18 - decimals));
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
      deployUpgradeable("AutomatedVaultManager", abi.encodeWithSelector(AutomatedVaultManager.initialize.selector))
    );
  }

  function deployBank(address moneyMarket, address vaultManager) internal returns (Bank) {
    return Bank(deployUpgradeable("Bank", abi.encodeWithSelector(Bank.initialize.selector, moneyMarket, vaultManager)));
  }

  function deployLiquidityOracle(address nftPositionManager, uint16 maxPriceAge, uint16 maxPriceDiff)
    internal
    returns (CommonV3LiquidityOracle)
  {
    return CommonV3LiquidityOracle(
      deployUpgradeable(
        "CommonV3LiquidityOracle",
        abi.encodeWithSelector(
          CommonV3LiquidityOracle.initialize.selector, nftPositionManager, maxPriceAge, maxPriceDiff
        )
      )
    );
  }

  function deployPancakeV3Worker(PancakeV3Worker.ConstructorParams memory params) internal returns (PancakeV3Worker) {
    return PancakeV3Worker(
      deployUpgradeable(
        "PancakeV3Worker",
        abi.encodeWithSelector(
          PancakeV3Worker.initialize.selector,
          address(params.vaultManager),
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

  function deployAndSeedMockMoneyMarket(address[] memory tokensToSeed)
    internal
    returns (MockMoneyMarket mockMoneyMarket)
  {
    mockMoneyMarket = new MockMoneyMarket();
    for (uint256 i = 0; i < tokensToSeed.length; ++i) {
      deal(tokensToSeed[i], address(mockMoneyMarket), 100 ether);
    }
  }
}
