// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { StdCheats } from "@forge-std/StdCheats.sol";
import { Vm } from "@forge-std/Vm.sol";

abstract contract TestConfigs is StdCheats {
  Vm private constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

  // Constants
  uint256 internal constant DUST = 0.000000001 ether;

  // User addresses
  address constant DEPLOYER = 0xC44f82b07Ab3E691F826951a6E335E1bC1bB0B51;
  address ALICE = makeAddr("ALICE");
  address BOB = makeAddr("BOB");
  address CHARLIE = makeAddr("CHARLIE");
  address EVE = makeAddr("EVE");
  address PERFORMANCE_FEE_BUCKET = makeAddr("PERFORMANCE_FEE_BUCKET");

  constructor() {
    vm.label(DEPLOYER, "DEPLOYER");
  }
}
