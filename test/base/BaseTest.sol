// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/Test.sol";

import { TestHelpers } from "./TestHelpers.sol";
import { TestConfigs } from "./TestConfigs.sol";

abstract contract BaseTest is Test, TestHelpers, TestConfigs {
  function setUp() public virtual { }
}
