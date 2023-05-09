// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./BasePancakeV3Worker.unit.sol";

contract PancakeV3Worker_Reinvest_UnitForkTest is BasePancakeV3WorkerUnitForkTest {
  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_WhenInRange_WhenReinvest() external {
    // Assert
    // - Worker's tokenId must be 0
    assertEq(worker.nftTokenId(), 0, "tokenId must be 0");

    // Increase position by 10_000 TKN0 and 1 TKN1
    vm.prank(IN_SCOPE_EXECUTOR);
    worker.doWork(address(this), Tasks.INCREASE, abi.encode(10_000 ether, 1 ether));

    // Assuming some trades happened
    _swapExactInput(address(token1), address(token0), poolFee, 500 ether);

    // Now call reinvest
    worker.reinvest();
  }
}
