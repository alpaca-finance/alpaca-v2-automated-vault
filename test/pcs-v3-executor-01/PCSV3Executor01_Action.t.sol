// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/Test.sol";

import { PCSV3Executor01 } from "src/executors/PCSV3Executor01.sol";
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";

import { MockERC20 } from "test/mocks/MockERC20.sol";

contract PCSV3Executor01ActionTest is Test {
  PCSV3Executor01 executor;
  address mockWorker = makeAddr("mockWorker");
  MockERC20 mockToken0;
  MockERC20 mockToken1;

  function setUp() public {
    executor = new PCSV3Executor01(address(0));
    mockToken0 = new MockERC20("Mock Token0", "MTKN0", 18);
    mockToken1 = new MockERC20("Mock Token1", "MTKN1", 6);
  }
}

contract PCSV3Executor01IncreasePositionTest is PCSV3Executor01ActionTest {
  function testCorrectness_IncreasePosition_SelfCall_PositionExist() public {
    vm.mockCall(mockWorker, abi.encodeWithSignature("nftTokenId()"), abi.encode(1234));
    vm.mockCall(mockWorker, abi.encodeWithSignature("token0()"), abi.encode(address(mockToken0)));
    vm.mockCall(mockWorker, abi.encodeWithSignature("token1()"), abi.encode(address(mockToken1)));
    vm.mockCall(mockWorker, abi.encodeWithSignature("increasePosition(uint256,uint256)"), abi.encode(0, 0, 0));

    vm.expectCall(mockWorker, abi.encodeWithSignature("increasePosition(uint256,uint256)"), 1);

    vm.prank(address(executor));
    executor.increasePosition(PancakeV3Worker(mockWorker), 1 ether, 1e6);
  }

  function testRevert_IncreasePosition_SelfCall_PositionNotExist() public {
    vm.mockCall(mockWorker, abi.encodeWithSignature("nftTokenId()"), abi.encode(0));

    vm.expectCall(mockWorker, abi.encodeWithSignature("increasePosition(uint256,uint256)"), 0);

    vm.prank(address(executor));
    vm.expectRevert(PCSV3Executor01.PCSV3Executor01_PositionNotExist.selector);
    executor.increasePosition(PancakeV3Worker(mockWorker), 1 ether, 1e6);
  }

  function testRevert_IncreasePosition_NotSelfCall() public {
    vm.prank(address(1234));
    vm.expectRevert(PCSV3Executor01.PCSV3Executor01_NotSelf.selector);
    executor.increasePosition(PancakeV3Worker(mockWorker), 1 ether, 1e6);
  }
}

contract PCSV3Executor01OpenPositionTest is PCSV3Executor01ActionTest {
  function testCorrectness_OpenPosition_SelfCall_PositionNotExist() public {
    vm.mockCall(mockWorker, abi.encodeWithSignature("nftTokenId()"), abi.encode(0));
    vm.mockCall(mockWorker, abi.encodeWithSignature("token0()"), abi.encode(address(mockToken0)));
    vm.mockCall(mockWorker, abi.encodeWithSignature("token1()"), abi.encode(address(mockToken1)));
    vm.mockCall(mockWorker, abi.encodeWithSignature("setTicks(int24,int24)"), abi.encode());
    vm.mockCall(mockWorker, abi.encodeWithSignature("increasePosition(uint256,uint256)"), abi.encode(0, 0, 0));

    vm.expectCall(mockWorker, abi.encodeWithSignature("setTicks(int24,int24)"), 1);
    vm.expectCall(mockWorker, abi.encodeWithSignature("increasePosition(uint256,uint256)"), 1);

    vm.prank(address(executor));
    executor.openPosition(PancakeV3Worker(mockWorker), 1, 1, 1 ether, 1e6);
  }

  function testRevert_OpenPosition_SelfCall_PositionExist() public {
    vm.mockCall(mockWorker, abi.encodeWithSignature("nftTokenId()"), abi.encode(1234));

    vm.expectCall(mockWorker, abi.encodeWithSignature("increasePosition(uint256,uint256)"), 0);

    vm.prank(address(executor));
    vm.expectRevert(PCSV3Executor01.PCSV3Executor01_PositionAlreadyExist.selector);
    executor.openPosition(PancakeV3Worker(mockWorker), 1, 2, 1 ether, 1e6);
  }

  function testRevert_OpenPosition_NotSelfCall() public {
    vm.prank(address(1234));
    vm.expectRevert(PCSV3Executor01.PCSV3Executor01_NotSelf.selector);
    executor.openPosition(PancakeV3Worker(mockWorker), 1, 2, 1 ether, 1e6);
  }
}
