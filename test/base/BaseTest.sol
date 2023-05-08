// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/Test.sol";

import { TestHelpers } from "./TestHelpers.sol";
import { TestConfigs } from "./TestConfigs.sol";

abstract contract BaseTest is Test, TestHelpers, TestConfigs {
  function setUp() public virtual {
    deal(ALICE, 100 ether);
    deal(BOB, 100 ether);
    deal(CHARLIE, 100 ether);
    deal(DEPLOYER, 100 ether);
    deal(EVE, 100 ether);
  }
}
