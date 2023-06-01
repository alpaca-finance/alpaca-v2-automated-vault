// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.19;

// import { ERC20 } from "@solmate/tokens/ERC20.sol";

// import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
// import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";

// import { IAutomatedVaultManager } from "src/interfaces/IAutomatedVaultManager.sol";
// import { IPancakeV3Router } from "src/interfaces/pancake-v3/IPancakeV3Router.sol";

// import { Tasks } from "src/libraries/Constants.sol";

// // fixtures
// import "test/fixtures/BscFixture.f.sol";
// import "test/fixtures/ProtocolActorFixture.f.sol";

// // helpers
// import { DeployHelper } from "test/helpers/DeployHelper.sol";

// contract BasePancakeV3WorkerTest is BscFixture, ProtocolActorFixture {
//   int24 internal constant TICK_LOWER = -58000;
//   int24 internal constant TICK_UPPER = -57750;
//   uint16 internal constant PERFORMANCE_FEE_BPS = 100;
//   uint256 internal constant DUST = 0.000000001 ether;

//   PancakeV3Worker worker;
//   ERC20 token0;
//   ERC20 token1;
//   uint24 poolFee;
//   IAutomatedVaultManager vaultManager = IAutomatedVaultManager(address(1));
//   address IN_SCOPE_EXECUTOR = makeAddr("IN_SCOPE_EXECUTOR");

//   constructor() BscFixture() ProtocolActorFixture() {
//     vm.createSelectFork("bsc_mainnet", 27_515_914);

//     vm.prank(DEPLOYER);
//     worker = PancakeV3Worker(
//       DeployHelper.deployUpgradeable(
//         "PancakeV3Worker",
//         abi.encodeWithSelector(
//           PancakeV3Worker.initialize.selector,
//           PancakeV3Worker.ConstructorParams({
//             vaultManager: vaultManager,
//             positionManager: pancakeV3PositionManager,
//             pool: pancakeV3USDTWBNBPool,
//             router: pancakeV3Router,
//             masterChef: pancakeV3MasterChef,
//             zapV3: zapV3,
//             performanceFeeBucket: PERFORMANCE_FEE_BUCKET,
//             tickLower: TICK_LOWER,
//             tickUpper: TICK_UPPER,
//             performanceFeeBps: PERFORMANCE_FEE_BPS
//           })
//         )
//       )
//     );

//     token0 = worker.token0();
//     token1 = worker.token1();
//     poolFee = worker.poolFee();

//     vm.mockCall(
//       address(vaultManager),
//       abi.encodeWithSelector(IAutomatedVaultManager.EXECUTOR_IN_SCOPE.selector),
//       abi.encode(IN_SCOPE_EXECUTOR)
//     );

//     vm.startPrank(IN_SCOPE_EXECUTOR);
//     token0.approve(address(worker), type(uint256).max);
//     token1.approve(address(worker), type(uint256).max);
//     vm.stopPrank();

//     deal(address(token0), IN_SCOPE_EXECUTOR, 100_000 ether);
//     deal(address(token1), IN_SCOPE_EXECUTOR, 100_000 ether);
//   }

//   struct CommonV3ImportantPositionInfo {
//     address token0;
//     address token1;
//     int24 tickLower;
//     int24 tickUpper;
//     uint128 liquidity;
//     uint128 tokensOwed0;
//     uint128 tokensOwed1;
//   }

//   function _getImportantPositionInfo(uint256 tokenId) internal view returns (CommonV3ImportantPositionInfo memory info) {
//     (,, info.token0, info.token1,, info.tickLower, info.tickUpper, info.liquidity,,, info.tokensOwed0, info.tokensOwed1)
//     = pancakeV3PositionManager.positions(tokenId);
//   }

//   function _swapExactInput(address tokenIn_, address tokenOut_, uint24 fee_, uint256 swapAmount) internal {
//     deal(tokenIn_, address(this), swapAmount);
//     // Approve router to spend token1
//     ERC20(tokenIn_).approve(address(pancakeV3Router), swapAmount);
//     // Swap
//     pancakeV3Router.exactInputSingle(
//       IPancakeV3Router.ExactInputSingleParams({
//         tokenIn: tokenIn_,
//         tokenOut: tokenOut_,
//         fee: fee_,
//         recipient: address(this),
//         amountIn: swapAmount,
//         amountOutMinimum: 0,
//         sqrtPriceLimitX96: 0
//       })
//     );
//   }
// }

// contract PancakeV3Worker_IncreaseLiquidityTest is BasePancakeV3WorkerTest {
//   constructor() BasePancakeV3WorkerTest() { }

//   function testCorrectness_IncreaseLiquidity_InRange_Subsequently() public {
//     // Assert
//     // - Worker's tokenId must be 0
//     assertEq(worker.nftTokenId(), 0, "tokenId must be 0");

//     // Increase position by 10_000 TKN0 and 1 TKN1
//     vm.prank(IN_SCOPE_EXECUTOR);
//     worker.doWork(Tasks.INCREASE, abi.encode(10_000 ether, 1 ether));
//     worker.openPosition()

//     // Asserts:
//     // - token0 and token1 must left in worker less than DUST
//     // - tokenId must be 46528
//     assertLt(token0.balanceOf(address(worker)), DUST, "token0 must left in worker less than DUST");
//     assertLt(token1.balanceOf(address(worker)), DUST, "token1 must left in worker less than DUST");
//     assertEq(worker.nftTokenId(), 46528, "tokenId must be 46528");

//     CommonV3ImportantPositionInfo memory positionInfo = _getImportantPositionInfo(46528);
//     assertEq(positionInfo.tickLower, TICK_LOWER, "tickLower must be TICK_LOWER");
//     assertEq(positionInfo.tickUpper, TICK_UPPER, "tickUpper must be TICK_UPPER");
//     assertEq(positionInfo.liquidity, 45904151499858308508910, "liquidity must be 45904151499858308508910");
//     assertEq(positionInfo.tokensOwed0, 0, "tokensOwed0 must be 0");
//     assertEq(positionInfo.tokensOwed1, 0, "tokensOwed1 must be 0");

//     // Increase position by 10_000 TKN0 and 25_000 TKN1 again
//     vm.prank(IN_SCOPE_EXECUTOR);
//     worker.doWork(Tasks.INCREASE, abi.encode(10_000 ether, 25_000 ether));

//     // Assert:
//     // - token0 and token1 must left in worker less than DUST
//     // - Worker's tokenId must be 46528
//     // - Worker's position's liquidity must be 20_000 TKN0 and 50_000 TKN1
//     assertLt(token0.balanceOf(address(worker)), DUST, "token0 must left in worker less than DUST");
//     assertLt(token1.balanceOf(address(worker)), DUST, "token1 must left in worker less than DUST");
//     assertEq(worker.nftTokenId(), 46528, "tokenId must be 25902");

//     positionInfo = _getImportantPositionInfo(46528);
//     assertEq(positionInfo.tickLower, TICK_LOWER, "tickLower must be TICK_LOWER");
//     assertEq(positionInfo.tickUpper, TICK_UPPER, "tickUpper must be TICK_UPPER");
//     assertEq(positionInfo.liquidity, 36235370516829017460459509, "liquidity must be 36235370516829017460459509");
//     assertEq(positionInfo.tokensOwed0, 0, "tokensOwed0 must be 0");
//     assertEq(positionInfo.tokensOwed1, 3439773883040434, "tokensOwed1 must be 3439773883040434");
//   }

//   function testCorrectness_IncreaseLiquidity_OutOfRange_CurTickMoreThanTickUpper_AfterSwappedStillOutOfRange() public {
//     // Swap so that pool's current tick goes beyond TICK_UPPER
//     _swapExactInput(address(token1), address(token0), poolFee, 5_500 ether);

//     // Asserts:
//     // - pool's current tick goes beyond TICK_UPPER
//     // - pool's position should be out of range
//     (, int24 currTick,,,,,) = pancakeV3USDTWBNBPool.slot0();
//     assertGt(currTick, TICK_UPPER, "currTick must be more than TICK_UPPER");
//     assertFalse(TICK_LOWER <= currTick && currTick <= TICK_UPPER, "should out of range");

//     // Increase position by 10_000 USDT and 10 WBNB
//     vm.prank(IN_SCOPE_EXECUTOR);
//     worker.doWork(Tasks.INCREASE, abi.encode(10_000 ether, 10 ether));

//     // Assert:
//     // - token0 and token1 must NOT left in worker
//     // - Worker's tokenId must be 46528
//     assertEq(token0.balanceOf(address(worker)), 0, "worker's token0 must be 0");
//     assertEq(token1.balanceOf(address(worker)), 0, "worker's token1 must be 0");
//     assertEq(worker.nftTokenId(), 46528, "tokenId must be 46528");
//   }

//   function testCorrectness_IncreaseLiquidity_OutOfRange_CurTickMoreThanTickUpper_AfterSwappedInRange() public {
//     // Swap so that pool's current tick goes beyond TICK_UPPER
//     _swapExactInput(address(token1), address(token0), poolFee, 5_500 ether);

//     // Asserts:
//     // - pool's current tick goes beyond TICK_UPPER
//     // - pool's position should be out of range
//     (, int24 currTick,,,,,) = pancakeV3USDTWBNBPool.slot0();
//     assertGt(currTick, TICK_UPPER, "currTick must be more than TICK_UPPER");
//     assertFalse(TICK_LOWER <= currTick && currTick <= TICK_UPPER, "should out of range");

//     // Increase position by 10_000 USDT and 0 WBNB
//     vm.prank(IN_SCOPE_EXECUTOR);
//     worker.doWork(Tasks.INCREASE, abi.encode(10_000 ether, 0));

//     // Assert:
//     // - token0 and token1 must less than DUST
//     // - Worker's tokenId must be 46528
//     assertLt(token0.balanceOf(address(worker)), DUST, "worker's token0 must be less than DUST");
//     assertLt(token1.balanceOf(address(worker)), DUST, "worker's token1 must be less than DUST");
//     assertEq(worker.nftTokenId(), 46528, "tokenId must be 46528");
//   }

//   function testCorrectness_IncreaseLiquidity_OutOfRange_CurTickLessThanTickLower_AfterSwappedStillOutOfRange() public {
//     // Swap so that pool's current tick goes below TICK_LOWER
//     _swapExactInput(address(token0), address(token1), poolFee, 2_000_000 ether);

//     // Asserts:
//     // - pool's current tick goes below TICK_LOWER
//     // - pool's position should be out of range
//     (, int24 currTick,,,,,) = pancakeV3USDTWBNBPool.slot0();
//     assertTrue(currTick < TICK_LOWER, "currTick must be less than TICK_LOWER");
//     assertFalse(TICK_LOWER <= currTick && currTick <= TICK_UPPER, "should out of range");

//     // Increase position by 10_000 USDT and 1 WBNB
//     vm.prank(IN_SCOPE_EXECUTOR);
//     worker.doWork(Tasks.INCREASE, abi.encode(10_000 ether, 10 ether));

//     // Assert:
//     // - token0 and token1 must NOT left in worker
//     // - Worker's tokenId must be 46528
//     assertEq(token0.balanceOf(address(worker)), 0, "worker's token0 must be 0");
//     assertEq(token1.balanceOf(address(worker)), 0, "worker's token1 must be 0");
//     assertEq(worker.nftTokenId(), 46528, "tokenId must be 46528");
//   }

//   function testCorrectness_IncreaseLiquidity_OutOfRange_CurTickLessThanTickLower_AfterSwappedInRange() public {
//     // Swap so that pool's current tick goes below TICK_LOWER
//     _swapExactInput(address(token0), address(token1), poolFee, 2_000_000 ether);

//     // Asserts:
//     // - pool's current tick goes below TICK_LOWER
//     // - pool's position should be out of range
//     (, int24 currTick,,,,,) = pancakeV3USDTWBNBPool.slot0();
//     assertTrue(currTick < TICK_LOWER, "currTick must be less than TICK_LOWER");
//     assertFalse(TICK_LOWER <= currTick && currTick <= TICK_UPPER, "should out of range");

//     // Increase position by 0 USDT and 300 WBNB
//     vm.prank(IN_SCOPE_EXECUTOR);
//     worker.doWork(Tasks.INCREASE, abi.encode(0 ether, 300 ether));

//     // Assert:
//     // - token0 and token1 must NOT left in worker
//     // - Worker's tokenId must be 46528
//     assertLt(token0.balanceOf(address(worker)), DUST, "worker's token0 must less than DUST");
//     assertLt(token1.balanceOf(address(worker)), DUST, "worker's token1 must less than DUST");
//     assertEq(worker.nftTokenId(), 46528, "tokenId must be 46528");
//   }

//   function testRevert_NotExecutorInScopeCallDoWork() public {
//     // call from some address that is not in scope
//     vm.prank(USER_ALICE);
//     vm.expectRevert(PancakeV3Worker.PancakeV3Worker_Unauthorized.selector);
//     worker.doWork(Tasks.INCREASE, abi.encode());
//   }

//   function testRevert_CallDoWorkWithInvalidTask() public {
//     vm.prank(IN_SCOPE_EXECUTOR);
//     vm.expectRevert(PancakeV3Worker.PancakeV3Worker_InvalidTask.selector);
//     // use address.call as workaround to call worker with invalid task enum
//     (bool _success,) = address(worker).call(
//       abi.encodeWithSelector(PancakeV3Worker.doWork.selector, address(this), uint8(255), abi.encode())
//     );
//     _success; // to silence solc warning
//   }
// }

// // TODO: more test
// contract PancakeV3Worker_HarvestTest is BasePancakeV3WorkerTest {
//   constructor() BasePancakeV3WorkerTest() { }

//   function testCorrectness_WorkerHasNoUnClaimTrandingFeeAndReward_WhenHarvest_ShouldWork() external {
//     uint256 token0Before = token0.balanceOf(address(worker));
//     uint256 token1Before = token1.balanceOf(address(worker));
//     uint256 cakeBefore = cake.balanceOf(address(worker));

//     worker.harvest();

//     assertEq(token0Before, token0.balanceOf(address(worker)));
//     assertEq(token1Before, token1.balanceOf(address(worker)));
//     assertEq(cakeBefore, cake.balanceOf(address(worker)));
//   }

//   function testCorrectness_WorkerHasUnClaimTrandingFeeAndReward_WhenHarvest_ShouldWork() external {
//     // Increase position by 10_000 TKN0 and 1 TKN1
//     vm.prank(IN_SCOPE_EXECUTOR);
//     worker.doWork(Tasks.INCREASE, abi.encode(10_000 ether, 1 ether));

//     // Assuming some trades happened
//     // pool current Tick at -57856
//     _swapExactInput(address(token1), address(token0), poolFee, 500 ether);
//     _swapExactInput(address(token0), address(token1), poolFee, 500 ether);

//     // move block timestamp to bypass same blocktimeStamp check
//     vm.warp(block.timestamp + 100);

//     // snapshot evm state and get the actual reward of the worker for easy calculation
//     uint256 snapShotId = vm.snapshot();
//     vm.startPrank(address(worker));

//     (uint256 _token0CollectAmount, uint256 _token1CollectAmount) = pancakeV3MasterChef.collect(
//       IPancakeV3MasterChef.CollectParams({
//         tokenId: worker.nftTokenId(),
//         recipient: address(worker),
//         amount0Max: type(uint128).max,
//         amount1Max: type(uint128).max
//       })
//     );

//     uint256 _token0ToBucket = _token0CollectAmount * PERFORMANCE_FEE_BPS / 10_000;
//     uint256 _token1ToBucket = _token1CollectAmount * PERFORMANCE_FEE_BPS / 10_000;
//     uint256 _harvestAmount = pancakeV3MasterChef.harvest(worker.nftTokenId(), address(worker));
//     uint256 _cakeToBucket = _harvestAmount * PERFORMANCE_FEE_BPS / 10_000;
//     uint256 _swapAmount = _harvestAmount - _cakeToBucket;

//     cake.approve(address(pancakeV3Router), _swapAmount);
//     uint256 _token1SwapAmountOut = pancakeV3Router.exactInputSingle(
//       IPancakeV3Router.ExactInputSingleParams({
//         tokenIn: address(cake),
//         tokenOut: address(token1),
//         fee: poolFee,
//         recipient: address(worker),
//         amountIn: _swapAmount,
//         amountOutMinimum: 0,
//         sqrtPriceLimitX96: 0
//       })
//     );
//     vm.stopPrank();
//     vm.revertTo(snapShotId);

//     // call actual harvest
//     worker.harvest();

//     // Assert PERFORMANCE_FEE_BUCK Balance
//     // PERFORMANCE_FEE_BUCK get PERFORMANCE_FEE_BPS% from the total reward
//     assertEq(token0.balanceOf(PERFORMANCE_FEE_BUCKET), _token0ToBucket);
//     assertEq(token1.balanceOf(PERFORMANCE_FEE_BUCKET), _token1ToBucket);
//     assertEq(cake.balanceOf(PERFORMANCE_FEE_BUCKET), _cakeToBucket);

//     // Assert worker Balance
//     assertEq(token0.balanceOf(address(worker)), _token0CollectAmount - _token0ToBucket);
//     assertEq(token1.balanceOf(address(worker)), _token1CollectAmount + _token1SwapAmountOut - _token1ToBucket);
//     assertEq(cake.balanceOf(address(worker)), 0);
//   }
// }

// contract PancakeV3Worker_TransferTest is BasePancakeV3WorkerTest {
//   constructor() BasePancakeV3WorkerTest() { }

//   function testCorrectness_WhenTransferBackToExecutor_ShouldWork() external {
//     uint256 _amount = 1 ether;
//     deal(address(token1), address(worker), _amount);
//     uint256 _workerToken1AmountBefore = token1.balanceOf(address(worker));
//     uint256 _executorToken1AmountBefore = token1.balanceOf(IN_SCOPE_EXECUTOR);
//     vm.prank(IN_SCOPE_EXECUTOR);
//     worker.transfer(address(token1), IN_SCOPE_EXECUTOR, _amount);

//     assertEq(token1.balanceOf(address(worker)), _workerToken1AmountBefore - _amount);
//     assertEq(token1.balanceOf(address(IN_SCOPE_EXECUTOR)), _executorToken1AmountBefore + _amount);
//   }

//   function testRevert_WhenCallerIsNotExecutorInScope() external {
//     vm.expectRevert(PancakeV3Worker.PancakeV3Worker_Unauthorized.selector);
//     worker.transfer(address(token1), IN_SCOPE_EXECUTOR, 1 ether);
//   }

//   function testRevert_WhenDestinationAddressIsZero() external {
//     vm.prank(IN_SCOPE_EXECUTOR);
//     vm.expectRevert(PancakeV3Worker.PancakeV3Worker_InvalidParams.selector);
//     worker.transfer(address(token1), address(0), 1 ether);
//   }

//   function testRevert_WhenTransferAmountIsZero() external {
//     vm.prank(IN_SCOPE_EXECUTOR);
//     vm.expectRevert(PancakeV3Worker.PancakeV3Worker_InvalidParams.selector);
//     worker.transfer(address(token1), IN_SCOPE_EXECUTOR, 0);
//   }
// }
