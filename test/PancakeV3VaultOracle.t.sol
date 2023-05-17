// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// contracts
import { PancakeV3VaultOracle } from "src/oracles/PancakeV3VaultOracle.sol";

// interfaces
import { IERC20 } from "src/interfaces/IERC20.sol";

// fixtures
import "test/fixtures/BscFixture.f.sol";
import "test/fixtures/ProtocolActorFixture.f.sol";

// helpers
import { DeployHelper } from "test/helpers/DeployHelper.sol";

contract PancakeV3VaultOracleHarness is PancakeV3VaultOracle {
  function harness_getPositionValueUSD(
    address _pool,
    uint256 _tokenId,
    uint256 _token0OraclePrice,
    uint256 _token1OraclePrice
  ) external view returns (uint256) {
    return _getPositionValueUSD(_pool, _tokenId, _token0OraclePrice, _token1OraclePrice);
  }
}

contract PancakeV3VaultOracleTest is BscFixture, ProtocolActorFixture {
  PancakeV3VaultOracle oracle;
  PancakeV3VaultOracleHarness harness;
  address mockBank = makeAddr("mockBank");
  address mockVaultToken = makeAddr("mockVaultToken");
  address mockWorker = makeAddr("mockWorker");

  constructor() BscFixture() ProtocolActorFixture() {
    vm.createSelectFork("bsc_mainnet", BscFixture.FORK_BLOCK_NUMBER_1);

    vm.startPrank(DEPLOYER);
    harness = PancakeV3VaultOracleHarness(
      DeployHelper.deployUpgradeableFullPath(
        "./out/PancakeV3VaultOracle.t.sol/PancakeV3VaultOracleHarness.json",
        abi.encodeWithSelector(
          PancakeV3VaultOracle.initialize.selector, address(pancakeV3PositionManager), mockBank, 100, 10_500
        )
      )
    );
    vm.stopPrank();
  }

  function _addLiquidity(
    ICommonV3Pool pool,
    int24 tickLower,
    int24 tickUpper,
    uint256 amount0Desired,
    uint256 amount1Desired
  ) internal returns (uint256 tokenId, uint256 amount0, uint256 amount1) {
    deal(pool.token0(), address(this), amount0Desired);
    deal(pool.token1(), address(this), amount1Desired);

    IERC20(pool.token0()).approve(address(pancakeV3PositionManager), type(uint256).max);
    IERC20(pool.token1()).approve(address(pancakeV3PositionManager), type(uint256).max);

    (tokenId,, amount0, amount1) = pancakeV3PositionManager.mint(
      ICommonV3PositionManager.MintParams({
        token0: pool.token0(),
        token1: pool.token1(),
        fee: pool.fee(),
        tickLower: tickLower,
        tickUpper: tickUpper,
        amount0Desired: amount0Desired,
        amount1Desired: amount1Desired,
        amount0Min: 0,
        amount1Min: 0,
        recipient: address(this),
        deadline: block.timestamp
      })
    );
  }

  function testForkFuzz_Harness_GetPositionValueUSD_InRange(
    int24 tickLower,
    int24 tickUpper,
    uint256 amount0Desired,
    uint256 amount1Desired
  ) public {
    // Bound to valid tick in range
    (, int24 tickCurrent,,,,,) = pancakeV3USDTWBNBPool.slot0();
    tickLower = int24(bound(tickLower, -887272, tickCurrent - 1));
    tickUpper = int24(bound(tickUpper, tickCurrent + 1, 887272));
    // Round tick to nearest valid tick according to tick spacing
    int24 tickSpacing = pancakeV3USDTWBNBPool.tickSpacing();
    tickLower = tickLower + tickSpacing - tickLower % tickSpacing;
    tickUpper = tickUpper - tickSpacing - tickUpper % tickSpacing;

    // Bound to sensible amount
    amount0Desired = bound(amount0Desired, 1e3, 1e32);
    amount1Desired = bound(amount1Desired, 1e3, 1e32);

    (uint256 tokenId, uint256 amount0, uint256 amount1) =
      _addLiquidity(pancakeV3USDTWBNBPool, tickLower, tickUpper, amount0Desired, amount1Desired);

    (, int256 usdtPrice,,,) = usdtFeed.latestRoundData();
    (, int256 wbnbPrice,,,) = wbnbFeed.latestRoundData();

    uint256 positionValueUSD = harness.harness_getPositionValueUSD(
      address(pancakeV3USDTWBNBPool),
      tokenId,
      uint256(usdtPrice) * (10 ** (18 - usdtFeed.decimals())),
      uint256(wbnbPrice) * (10 ** (18 - wbnbFeed.decimals()))
    );

    uint256 usdtValueUSD = amount0 * uint256(usdtPrice) / (10 ** usdtFeed.decimals());
    uint256 wbnbValueUSD = amount1 * uint256(wbnbPrice) / (10 ** wbnbFeed.decimals());
    uint256 expectedPositionValueUSD = usdtValueUSD + wbnbValueUSD;

    // There is always 1 wei loss when convert liquidty to amount
    // `1e18 / lesserAmount` is to define that loss as max delta
    uint256 maxDelta;
    if (amount0 == 0) maxDelta = 1e18 / amount1;
    else if (amount1 == 0) maxDelta = 1e18 / amount0;
    else maxDelta = 1e18 / (amount0 < amount1 ? amount0 : amount1);
    assertApproxEqRel(positionValueUSD, expectedPositionValueUSD, maxDelta);
  }

  //   function testForkFuzz_GetPositionValue_BothTokenE18(
  //     uint96 usdtBorrowAmount,
  //     uint96 wbnbBorrowAmount,
  //     uint96 usdtAddLiquidityAmount,
  //     uint96 wbnbAddLiquidityAmount
  //   ) public {
  //     vm.assume(usdtBorrowAmount > 1e18);
  //     vm.assume(wbnbBorrowAmount > 1e18);
  //     vm.assume(usdtAddLiquidityAmount > 1e18);
  //     vm.assume(wbnbAddLiquidityAmount > 1e18);

  //     // Deal tokens
  //     deal(address(wbnb), USER_ALICE, wbnbAddLiquidityAmount);
  //     deal(address(usdt), USER_ALICE, usdtAddLiquidityAmount);

  //     // Setup oracle
  //     vm.startPrank(DEPLOYER);
  //     oracle.setPriceFeedOf(address(usdt), address(usdtFeed));
  //     oracle.setPriceFeedOf(address(wbnb), address(wbnbFeed));
  //     oracle.setMaxPriceAge(6_000);
  //     oracle.setMaxPriceDiff(10_500);
  //     vm.stopPrank();

  //     // Add liquidity
  //     vm.startPrank(USER_ALICE);
  //     wbnb.approve(address(pancakeV3PositionManager), type(uint256).max);
  //     usdt.approve(address(pancakeV3PositionManager), type(uint256).max);
  //     (uint256 tokenId,, uint256 amount0, uint256 amount1) = pancakeV3PositionManager.mint(
  //       ICommonV3PositionManager.MintParams({
  //         token0: pancakeV3USDTWBNBPool.token0(),
  //         token1: pancakeV3USDTWBNBPool.token1(),
  //         fee: pancakeV3USDTWBNBPool.fee(),
  //         tickLower: -58000,
  //         tickUpper: -57750,
  //         amount0Desired: usdtAddLiquidityAmount,
  //         amount1Desired: wbnbAddLiquidityAmount,
  //         amount0Min: 0,
  //         amount1Min: 0,
  //         recipient: address(this),
  //         deadline: block.timestamp
  //       })
  //     );
  //     vm.stopPrank();

  //     // Calculate expected value
  //     (, int256 usdtPrice,,,) = usdtFeed.latestRoundData();
  //     (, int256 wbnbPrice,,,) = wbnbFeed.latestRoundData();
  //     uint256 expectedPositionValueUSD = amount0 * uint256(usdtPrice) / (10 ** usdtFeed.decimals())
  //       + amount1 * uint256(wbnbPrice) / (10 ** wbnbFeed.decimals());
  //     uint256 expectedDebtValueUSD = usdtBorrowAmount * uint256(usdtPrice) / (10 ** usdtFeed.decimals())
  //       + wbnbBorrowAmount * uint256(wbnbPrice) / (10 ** wbnbFeed.decimals());

  //     // Discard debt > position * 1.1 value
  //     vm.assume(expectedDebtValueUSD * 11 / 10 < expectedPositionValueUSD);

  //     // Mock borrow
  //     vm.mockCall(
  //       mockBank,
  //       abi.encodeWithSignature("getVaultDebt(address,address)", mockVaultToken, address(usdt)),
  //       abi.encode(0, usdtBorrowAmount)
  //     );
  //     vm.mockCall(
  //       mockBank,
  //       abi.encodeWithSignature("getVaultDebt(address,address)", mockVaultToken, address(wbnb)),
  //       abi.encode(0, wbnbBorrowAmount)
  //     );

  //     // Mock worker
  //     vm.mockCall(mockWorker, abi.encodeWithSignature("pool()"), abi.encode(address(pancakeV3USDTWBNBPool)));
  //     vm.mockCall(mockWorker, abi.encodeWithSignature("nftTokenId()"), abi.encode(tokenId));

  //     console.log(expectedPositionValueUSD);
  //     console.log(expectedDebtValueUSD);
  //     assertApproxEqAbs(
  //       oracle.getEquity(mockVaultToken, mockWorker), expectedPositionValueUSD - expectedDebtValueUSD, 1e18
  //     );

  //     // uint256 oracleValueUSD = oracle.getPositionValueUSD(address(pancakeV3USDTWBNBPool), tokenId);

  //     // (, int256 usdtPrice,,,) = usdtFeed.latestRoundData();
  //     // uint256 usdtValueUSD = amount0 * uint256(usdtPrice) / (10 ** usdtFeed.decimals());
  //     // (, int256 wbnbPrice,,,) = wbnbFeed.latestRoundData();
  //     // uint256 wbnbValueUSD = amount1 * uint256(wbnbPrice) / (10 ** wbnbFeed.decimals());
  //     // uint256 expectedPositionValueUSD = usdtValueUSD + wbnbValueUSD;

  //     // assertApproxEqAbs(oracleValueUSD, expectedPositionValueUSD, 328);

  //     // emit log_named_decimal_uint("amount0 (USDT)", amount0, 18);
  //     // emit log_named_decimal_uint("amount1 (WBNB)", amount1, 18);
  //     // emit log_named_decimal_uint("usdtValue     ", usdtValueUSD, 18);
  //     // emit log_named_decimal_uint("wbnbValue     ", wbnbValueUSD, 18);
  //     // emit log_named_decimal_uint("expectedValue ", expectedPositionValueUSD, 18);
  //     // emit log_named_decimal_uint("oracleValueUSD", oracleValueUSD, 18);
  //     // emit log_named_uint("deltaAbs      ", stdMath.delta(oracleValueUSD, expectedPositionValueUSD));
  //     // emit log_named_decimal_uint("deltaRel      ", stdMath.percentDelta(oracleValueUSD, expectedPositionValueUSD), 16);
  //   }

  //   function testForkFuzz_GetEquity(
  //     int24 tickLower,
  //     int24 tickUpper,
  //     uint160 usdtBorrowAmount,
  //     uint160 wbnbBorrowAmount,
  //     uint160 usdtAddLiquidityAmount,
  //     uint160 wbnbAddLiquidityAmount
  //   ) public {
  //     // Assume valid tick range
  //     // int24 tickSpacing = pancakeV3USDTWBNBPool.tickSpacing();
  //     (, int24 tickCurrent,,,,,) = pancakeV3USDTWBNBPool.slot0();
  //     // bound(tickLower, -887272, 887272);
  //     // bound(tickUpper, -887272, 887272);
  //     bound(tickLower, tickCurrent - 100000, tickCurrent);
  //     bound(tickUpper, tickCurrent, tickCurrent + 100000);
  //     vm.assume(tickLower < tickUpper);
  //     // vm.assume(tickLower % tickSpacing == 0);
  //     // vm.assume(tickUpper % tickSpacing == 0);

  //     // Deal tokens
  //     deal(address(wbnb), USER_ALICE, wbnbAddLiquidityAmount);
  //     deal(address(usdt), USER_ALICE, usdtAddLiquidityAmount);

  //     // Add liquidity
  //     vm.startPrank(USER_ALICE);
  //     (uint256 tokenId,, uint256 amount0, uint256 amount1) = pancakeV3PositionManager.mint(
  //       ICommonV3PositionManager.MintParams({
  //         token0: pancakeV3USDTWBNBPool.token0(),
  //         token1: pancakeV3USDTWBNBPool.token1(),
  //         fee: pancakeV3USDTWBNBPool.fee(),
  //         tickLower: tickLower,
  //         tickUpper: tickUpper,
  //         amount0Desired: usdtAddLiquidityAmount,
  //         amount1Desired: wbnbAddLiquidityAmount,
  //         amount0Min: 0,
  //         amount1Min: 0,
  //         recipient: address(this),
  //         deadline: block.timestamp
  //       })
  //     );
  //     vm.stopPrank();

  //     // Mock borrow
  //     vm.mockCall(
  //       mockBank,
  //       abi.encodeWithSignature("getVaultDebt(address,address)", mockVaultToken, address(usdt)),
  //       abi.encode(0, usdtBorrowAmount)
  //     );
  //     vm.mockCall(
  //       mockBank,
  //       abi.encodeWithSignature("getVaultDebt(address,address)", mockVaultToken, address(wbnb)),
  //       abi.encode(0, wbnbBorrowAmount)
  //     );

  //     // Mock worker
  //     vm.mockCall(mockWorker, abi.encodeWithSignature("pool()"), abi.encode(address(pancakeV3USDTWBNBPool)));
  //     vm.mockCall(mockWorker, abi.encodeWithSignature("nftTokenId()"), abi.encode(tokenId));

  //     // Calculate expected value
  //     (, int256 usdtPrice,,,) = usdtFeed.latestRoundData();
  //     (, int256 wbnbPrice,,,) = wbnbFeed.latestRoundData();
  //     uint256 expectedPositionValueUSD = amount0 * uint256(usdtPrice) / (10 ** usdtFeed.decimals())
  //       + amount1 * uint256(wbnbPrice) / (10 ** wbnbFeed.decimals());
  //     uint256 expectedDebtValueUSD = usdtBorrowAmount * uint256(usdtPrice) / (10 ** usdtFeed.decimals())
  //       + wbnbBorrowAmount * uint256(wbnbPrice) / (10 ** wbnbFeed.decimals());

  //     assertEq(oracle.getEquity(mockVaultToken, mockWorker), expectedPositionValueUSD + expectedDebtValueUSD);
  //   }
}
