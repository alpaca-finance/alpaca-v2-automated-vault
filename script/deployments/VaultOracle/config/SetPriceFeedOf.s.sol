// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { BaseOracle } from "src/oracles/BaseOracle.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

contract SetPriceFeedOfScript is BaseScript {
  function run() public {
    address _vaultOracle = 0x42f3A6c5e555a83F00208340b60aE2643CE90a62;
    address _wbnbChainLinkPricefeed = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;
    address _usdtChainLinkPriceFeed = 0xB97Ad0E74fa7d920791E90258A6E2085088b4320;

    vm.startBroadcast(deployerPrivateKey);

    BaseOracle(_vaultOracle).setPriceFeedOf(wbnb, _wbnbChainLinkPricefeed);
    BaseOracle(_vaultOracle).setPriceFeedOf(usdt, _usdtChainLinkPriceFeed);

    vm.stopBroadcast();
  }
}
