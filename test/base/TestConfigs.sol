// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/StdCheats.sol";

abstract contract TestConfigs is StdCheats {
  address DEPLOYER = makeAddr("DEPLOYER");
  address ALICE = makeAddr("ALICE");
  address BOB = makeAddr("BOB");
  address CHARLIE = makeAddr("CHARLIE");
  address EVE = makeAddr("EVE");
}
