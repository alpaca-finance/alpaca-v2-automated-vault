// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { BaseTest } from "./BaseTest.sol";
import { ForkTestConfigs } from "./ForkTestConfigs.sol";

abstract contract BaseForkTest is BaseTest, ForkTestConfigs {
  function setUp() public virtual override {
    super.setUp();

    vm.createSelectFork("bsc_mainnet", 27_515_914);
  }
}
