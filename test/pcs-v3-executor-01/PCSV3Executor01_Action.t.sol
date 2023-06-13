// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/Test.sol";

import { Executor } from "src/executors/Executor.sol";
import { PCSV3Executor01 } from "src/executors/PCSV3Executor01.sol";
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";

import { MockERC20 } from "test/mocks/MockERC20.sol";

import "test/fixtures/BscFixture.f.sol";

contract PCSV3Executor01ActionTest is Test {
  PCSV3Executor01 executor;
  address mockWorker = makeAddr("mockWorker");
  address mockVaultManager = makeAddr("mockVaultManager");
  address mockBank = makeAddr("mockBank");
  address mockVaultToken = makeAddr("mockVaultToken");
  MockERC20 mockToken0;
  MockERC20 mockToken1;

  function setUp() public virtual {
    executor = new PCSV3Executor01(mockVaultManager,mockBank);

    mockToken0 = new MockERC20("Mock Token0", "MTKN0", 18);
    mockToken1 = new MockERC20("Mock Token1", "MTKN1", 6);
  }
}

contract PCSV3Executor01IncreasePositionTest is PCSV3Executor01ActionTest {
  function testCorrectness_IncreasePosition_VaultManagerIsCaller() public {
    vm.mockCall(mockWorker, abi.encodeWithSignature("token0()"), abi.encode(address(mockToken0)));
    vm.mockCall(mockWorker, abi.encodeWithSignature("token1()"), abi.encode(address(mockToken1)));
    vm.mockCall(mockWorker, abi.encodeWithSignature("increasePosition(uint256,uint256)"), abi.encode());
    vm.prank(mockVaultManager);
    executor.setExecutionScope(mockWorker, mockVaultToken);

    vm.expectCall(mockWorker, abi.encodeWithSignature("increasePosition(uint256,uint256)"), 1);

    vm.prank(mockVaultManager);
    executor.increasePosition(1 ether, 1e6);
  }

  function testRevert_IncreasePosition_CallerIsNotVaultManager() public {
    vm.prank(address(1234));
    vm.expectRevert(Executor.Executor_NotVaultManager.selector);
    executor.increasePosition(1 ether, 1e6);
  }
}

contract PCSV3Executor01OpenPositionTest is PCSV3Executor01ActionTest {
  function testCorrectness_OpenPosition_VaultManagerIsCaller_PositionNotExist() public {
    vm.mockCall(mockWorker, abi.encodeWithSignature("token0()"), abi.encode(address(mockToken0)));
    vm.mockCall(mockWorker, abi.encodeWithSignature("token1()"), abi.encode(address(mockToken1)));
    vm.mockCall(mockWorker, abi.encodeWithSignature("openPosition(int24,int24,uint256,uint256)"), abi.encode());
    vm.prank(mockVaultManager);
    executor.setExecutionScope(mockWorker, mockVaultToken);

    vm.expectCall(mockWorker, abi.encodeWithSignature("openPosition(int24,int24,uint256,uint256)"), 1);

    vm.prank(mockVaultManager);
    executor.openPosition(1, 1, 1 ether, 1e6);
  }

  function testRevert_OpenPosition_CallerIsNotVaultManager() public {
    vm.prank(address(1234));
    vm.expectRevert(Executor.Executor_NotVaultManager.selector);
    executor.openPosition(1, 2, 1 ether, 1e6);
  }
}

contract PCSV3Executor01DecreasePositionTest is PCSV3Executor01ActionTest {
  function testCorrectness_DecreasePosition_WorkerScopeSet() public {
    vm.mockCall(mockWorker, abi.encodeWithSignature("decreasePosition(uint128)"), abi.encode(0, 0));
    vm.prank(mockVaultManager);
    executor.setExecutionScope(mockWorker, mockVaultToken);

    vm.expectCall(mockWorker, abi.encodeWithSignature("decreasePosition(uint128)"), 1);

    vm.prank(mockVaultManager);
    executor.decreasePosition(1 ether);
  }

  function testRevert_DecreasePosition_WorkerScopeNotSet() public {
    vm.prank(mockVaultManager);
    executor.setExecutionScope(address(0), mockVaultToken);

    vm.expectCall(mockWorker, abi.encodeWithSignature("decreasePosition(uint128)"), 0);

    vm.prank(mockVaultManager);
    vm.expectRevert(Executor.Executor_NoCurrentWorker.selector);
    executor.decreasePosition(1 ether);
  }

  function testRevert_DecreasePosition_CallerIsNotVaultManager() public {
    vm.prank(address(1234));
    vm.expectRevert(Executor.Executor_NotVaultManager.selector);
    executor.decreasePosition(1 ether);
  }
}

contract PCSV3Executor01ClosePositionTest is PCSV3Executor01ActionTest {
  function testCorrectness_ClosePosition_WorkerScopeSet() public {
    vm.mockCall(mockWorker, abi.encodeWithSignature("closePosition()"), abi.encode());
    vm.prank(mockVaultManager);
    executor.setExecutionScope(mockWorker, mockVaultToken);

    vm.expectCall(mockWorker, abi.encodeWithSignature("closePosition()"), 1);

    vm.prank(mockVaultManager);
    executor.closePosition();
  }

  function testRevert_ClosePosition_WorkerScopeNotSet() public {
    vm.prank(mockVaultManager);
    executor.setExecutionScope(address(0), mockVaultToken);

    vm.expectCall(mockWorker, abi.encodeWithSignature("closePosition()"), 0);

    vm.prank(mockVaultManager);
    vm.expectRevert(Executor.Executor_NoCurrentWorker.selector);
    executor.closePosition();
  }

  function testRevert_ClosePosition_CallerIsNotVaultManager() public {
    vm.prank(address(1234));
    vm.expectRevert(Executor.Executor_NotVaultManager.selector);
    executor.closePosition();
  }
}

contract PCSV3Executor01TransferTest is PCSV3Executor01ActionTest {
  function testCorrectness_TransferFromWorker_CallerIsVaultManager() public {
    vm.mockCall(mockWorker, abi.encodeWithSignature("transfer(address,uint256)"), abi.encode());
    vm.mockCall(mockVaultManager, abi.encodeWithSignature("EXECUTOR_IN_SCOPE()"), abi.encode(address(executor)));
    vm.prank(mockVaultManager);
    executor.setExecutionScope(mockWorker, mockVaultToken);

    vm.expectCall(mockWorker, abi.encodeWithSignature("transfer(address,uint256)"), 1);

    vm.prank(mockVaultManager);
    executor.transferFromWorker(address(mockToken0), 1 ether);
  }

  function testCorrectness_TransferToWorker_CallerIsVaultManager() public {
    vm.prank(mockVaultManager);
    executor.setExecutionScope(mockWorker, mockVaultToken);

    deal(address(mockToken0), address(executor), 1 ether);
    uint256 balanceBefore = mockToken0.balanceOf(mockWorker);

    vm.prank(mockVaultManager);
    executor.transferToWorker(address(mockToken0), 1 ether);

    assertEq(mockToken0.balanceOf(mockWorker) - balanceBefore, 1 ether);
  }

  function testRevert_TransferFromWorker_CallerIsNotVaultManager() public {
    vm.prank(address(1234));
    vm.expectRevert(Executor.Executor_NotVaultManager.selector);
    executor.transferFromWorker(address(mockToken0), 1 ether);
  }

  function testRevert_TransferToWorker_CallerIsNotVaultManager() public {
    vm.prank(address(1234));
    vm.expectRevert(Executor.Executor_NotVaultManager.selector);
    executor.transferToWorker(address(mockToken0), 1 ether);
  }
}

contract PCSV3Executor01BorrowTest is PCSV3Executor01ActionTest {
  function testCorrectness_Borrow_CallerIsVaultManager() public {
    vm.mockCall(
      mockBank,
      abi.encodeWithSignature("borrowOnBehalfOf(address,address,uint256)", mockVaultToken, address(mockToken0), 1e18),
      abi.encode()
    );

    vm.expectCall(mockBank, abi.encodeWithSignature("borrowOnBehalfOf(address,address,uint256)"), 1);
    vm.startPrank(mockVaultManager);
    executor.setExecutionScope(mockWorker, mockVaultToken);
    executor.borrow(address(mockToken0), 1 ether);
  }

  function testRevert_Borrow_CallerIsNotVaultManager() public {
    vm.prank(address(1234));
    vm.expectRevert(Executor.Executor_NotVaultManager.selector);
    executor.borrow(address(mockToken0), 1e18);
  }
}

contract PCSV3Executor01RepayTest is PCSV3Executor01ActionTest {
  function testCorrectness_Repay_VaultManagerIsCaller() public {
    vm.mockCall(
      mockBank,
      abi.encodeWithSignature("repayOnBehalfOf(address,address,uint256)", mockVaultToken, address(mockToken0), 1e18),
      abi.encode()
    );

    vm.expectCall(mockBank, abi.encodeWithSignature("repayOnBehalfOf(address,address,uint256)"), 1);
    vm.startPrank(mockVaultManager);
    executor.setExecutionScope(mockWorker, mockVaultToken);
    executor.repay(address(mockToken0), 1e18);
  }

  function testRevert_Repay_CallerIsNotVaultManager() public {
    vm.prank(address(1234));
    vm.expectRevert(Executor.Executor_NotVaultManager.selector);
    executor.repay(address(mockToken0), 1e18);
  }
}

contract PCSV3Executor01PancakeV3SwapForkTest is PCSV3Executor01ActionTest, BscFixture {
  constructor() BscFixture() {
    vm.createSelectFork("bsc_mainnet", BscFixture.FORK_BLOCK_NUMBER_1);
  }

  function setUp() public override {
    super.setUp();

    executor = new PCSV3Executor01(mockVaultManager, address(0));
  }

  function testCorrectness_Executor_SwapExactInputSingle() public {
    deal(address(usdt), address(executor), 1 ether);

    vm.prank(mockVaultManager);
    executor.setExecutionScope(mockWorker, mockVaultToken);

    vm.mockCall(mockWorker, abi.encodeWithSignature("pool()"), abi.encode(address(pancakeV3USDTWBNBPool)));

    uint256 usdtBefore = usdt.balanceOf(address(executor));
    uint256 wbnbBefore = wbnb.balanceOf(address(executor));

    vm.prank(mockVaultManager);
    executor.pancakeV3SwapExactInputSingle(true, 1 ether);

    assertEq(usdtBefore - usdt.balanceOf(address(executor)), 1 ether);
    assertEq(wbnb.balanceOf(address(executor)) - wbnbBefore, 3068419005692078);
  }

  function testRevert_Swap_NotVaultManagerCall() public {
    vm.prank(address(1234));
    vm.expectRevert(Executor.Executor_NotVaultManager.selector);
    executor.pancakeV3SwapExactInputSingle(true, 1 ether);
  }

  function testRevert_Executor_PancakeV3SwapCallback_CallerIsNotPool() public {
    vm.prank(address(1234));
    vm.expectRevert(PCSV3Executor01.PCSV3Executor01_NotPool.selector);
    executor.pancakeV3SwapCallback(1, 1, abi.encode(address(usdt), address(wbnb), 500));
  }
}
