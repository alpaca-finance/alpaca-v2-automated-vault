// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/Test.sol";

import { Executor } from "src/executors/Executor.sol";
import { PCSV3Executor01 } from "src/executors/PCSV3Executor01.sol";
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";

import { MockERC20 } from "test/mocks/MockERC20.sol";

contract PCSV3Executor01ActionTest is Test {
  PCSV3Executor01 executor;
  address mockWorker = makeAddr("mockWorker");
  address mockVaultToken = makeAddr("mockVaultToken");
  address mockVaultManager = makeAddr("mockVaultManager");
  MockERC20 mockToken0;
  MockERC20 mockToken1;

  function setUp() public {
    executor = new PCSV3Executor01(mockVaultManager, address(0));
    mockToken0 = new MockERC20("Mock Token0", "MTKN0", 18);
    mockToken1 = new MockERC20("Mock Token1", "MTKN1", 6);
  }
}

contract PCSV3Executor01IncreasePositionTest is PCSV3Executor01ActionTest {
  function testCorrectness_IncreasePosition_SelfCall() public {
    vm.mockCall(mockWorker, abi.encodeWithSignature("token0()"), abi.encode(address(mockToken0)));
    vm.mockCall(mockWorker, abi.encodeWithSignature("token1()"), abi.encode(address(mockToken1)));
    vm.mockCall(mockWorker, abi.encodeWithSignature("increasePosition(uint256,uint256)"), abi.encode());
    vm.prank(mockVaultManager);
    executor.setExecutionScope(mockWorker, mockVaultToken);

    vm.expectCall(mockWorker, abi.encodeWithSignature("increasePosition(uint256,uint256)"), 1);

    vm.prank(address(executor));
    executor.increasePosition(1 ether, 1e6);
  }

  function testRevert_IncreasePosition_NotSelfCall() public {
    vm.prank(address(1234));
    vm.expectRevert(PCSV3Executor01.PCSV3Executor01_NotSelf.selector);
    executor.increasePosition(1 ether, 1e6);
  }
}

contract PCSV3Executor01OpenPositionTest is PCSV3Executor01ActionTest {
  function testCorrectness_OpenPosition_SelfCall_PositionNotExist() public {
    vm.mockCall(mockWorker, abi.encodeWithSignature("token0()"), abi.encode(address(mockToken0)));
    vm.mockCall(mockWorker, abi.encodeWithSignature("token1()"), abi.encode(address(mockToken1)));
    vm.mockCall(mockWorker, abi.encodeWithSignature("openPosition(int24,int24,uint256,uint256)"), abi.encode());
    vm.prank(mockVaultManager);
    executor.setExecutionScope(mockWorker, mockVaultToken);

    vm.expectCall(mockWorker, abi.encodeWithSignature("openPosition(int24,int24,uint256,uint256)"), 1);

    vm.prank(address(executor));
    executor.openPosition(1, 1, 1 ether, 1e6);
  }

  function testRevert_OpenPosition_NotSelfCall() public {
    vm.prank(address(1234));
    vm.expectRevert(PCSV3Executor01.PCSV3Executor01_NotSelf.selector);
    executor.openPosition(1, 2, 1 ether, 1e6);
  }
}

contract PCSV3Executor01DecreasePositionTest is PCSV3Executor01ActionTest {
  function testCorrectness_DecreasePosition_WorkerScopeSet() public {
    vm.mockCall(mockWorker, abi.encodeWithSignature("decreasePosition(uint128)"), abi.encode());
    vm.prank(mockVaultManager);
    executor.setExecutionScope(mockWorker, mockVaultToken);

    vm.expectCall(mockWorker, abi.encodeWithSignature("decreasePosition(uint128)"), 1);

    vm.prank(address(executor));
    executor.decreasePosition(1 ether);
  }

  function testRevert_DecreasePosition_WorkerScopeNotSet() public {
    vm.prank(mockVaultManager);
    executor.setExecutionScope(address(0), mockVaultToken);

    vm.expectCall(mockWorker, abi.encodeWithSignature("decreasePosition(uint128)"), 0);

    vm.prank(address(executor));
    vm.expectRevert(Executor.Executor_NoCurrentWorker.selector);
    executor.decreasePosition(1 ether);
  }
}

contract PCSV3Executor01ClosePositionTest is PCSV3Executor01ActionTest {
  function testCorrectness_ClosePosition_WorkerScopeSet() public {
    vm.mockCall(mockWorker, abi.encodeWithSignature("closePosition()"), abi.encode());
    vm.prank(mockVaultManager);
    executor.setExecutionScope(mockWorker, mockVaultToken);

    vm.expectCall(mockWorker, abi.encodeWithSignature("closePosition()"), 1);

    vm.prank(address(executor));
    executor.closePosition();
  }

  function testRevert_ClosePosition_WorkerScopeNotSet() public {
    vm.prank(mockVaultManager);
    executor.setExecutionScope(address(0), mockVaultToken);

    vm.expectCall(mockWorker, abi.encodeWithSignature("closePosition()"), 0);

    vm.prank(address(executor));
    vm.expectRevert(Executor.Executor_NoCurrentWorker.selector);
    executor.closePosition();
  }
}

contract PCSV3Executor01WithdrawUndeployedFundsTest is PCSV3Executor01ActionTest {
  function testCorrectness_WithdrawUndeployedFunds_WorkerScopeSet() public {
    vm.mockCall(mockWorker, abi.encodeWithSignature("withdrawUndeployedFunds(address,uint256)"), abi.encode());
    vm.prank(mockVaultManager);
    executor.setExecutionScope(mockWorker, mockVaultToken);

    vm.expectCall(mockWorker, abi.encodeWithSignature("withdrawUndeployedFunds(address,uint256)"), 1);

    vm.prank(address(executor));
    executor.withdrawUndeployedFunds(address(1), 1 ether);
  }

  function testRevert_WithdrawUndeployedFunds_WorkerScopeNotSet() public {
    vm.prank(mockVaultManager);
    executor.setExecutionScope(address(0), mockVaultToken);

    vm.expectCall(mockWorker, abi.encodeWithSignature("withdrawUndeployedFunds(address,uint256)"), 0);

    vm.prank(address(executor));
    vm.expectRevert(Executor.Executor_NoCurrentWorker.selector);
    executor.withdrawUndeployedFunds(address(1), 1 ether);
  }
}
