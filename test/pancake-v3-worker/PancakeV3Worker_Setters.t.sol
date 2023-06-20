// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// fixtures
import "test/fixtures/PancakeV3WorkerFixture.f.sol";

contract PancakeV3WorkerSettersTest is PancakeV3WorkerFixture {
  function testRevert_SetTradingPerformanceFee_CallerIsNotOwner() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    worker.setTradingPerformanceFee(1000);
  }

  function testRevert_SetTradingPerformanceFee_InvalidParam() public {
    vm.expectRevert(abi.encodeWithSignature("PancakeV3Worker_InvalidParams()"));
    worker.setTradingPerformanceFee(10001);
  }

  function testCorrectness_SetTradingPerformanceFee() public {
    worker.setTradingPerformanceFee(1000);
    assertEq(worker.tradingPerformanceFeeBps(), 1000);
  }

  function testRevert_SetRewardPerformanceFee_CallerIsNotOwner() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    worker.setRewardPerformanceFee(1000);
  }

  function testRevert_SetRewardPerformanceFee_InvalidParam() public {
    vm.expectRevert(abi.encodeWithSignature("PancakeV3Worker_InvalidParams()"));
    worker.setRewardPerformanceFee(10001);
  }

  function testCorrectness_SetRewardPerformanceFee() public {
    worker.setRewardPerformanceFee(1000);
    assertEq(worker.rewardPerformanceFeeBps(), 1000);
  }

  function testRevert_SetPerformanceFeeBucket_CallerIsNotOwner() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    worker.setPerformanceFeeBucket(address(1234));
  }

  function testRevert_SetPerformanceFeeBucket_InvalidParam() public {
    vm.expectRevert(abi.encodeWithSignature("PancakeV3Worker_InvalidParams()"));
    worker.setPerformanceFeeBucket(address(0));
  }

  function testCorrectness_SetPerformanceFeeBucket() public {
    worker.setPerformanceFeeBucket(address(1234));
    assertEq(worker.performanceFeeBucket(), address(1234));
  }
}
