// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./BaseCommonV3LiquidityOracle.unit.sol";

contract CommonV3LiquidityOracle_GetPositionValueUnitForkTest is BaseCommonV3LiquidityOracleUnitForkTest {
  function testCorrectness_GetPositionValue_BothTokenE18() public {
    (uint256 tokenId, uint256 amount0, uint256 amount1) = _mintUSDTWBNB();

    uint256 oracleValueUSD = liquidityOracle.getPositionValueUSD(address(pancakeV3USDTWBNBPool), tokenId);

    (, int256 usdtPrice,,,) = usdtFeed.latestRoundData();
    uint256 usdtValueUSD = amount0 * uint256(usdtPrice) / (10 ** usdtFeed.decimals());
    (, int256 wbnbPrice,,,) = wbnbFeed.latestRoundData();
    uint256 wbnbValueUSD = amount1 * uint256(wbnbPrice) / (10 ** wbnbFeed.decimals());
    uint256 expectedPositionValueUSD = usdtValueUSD + wbnbValueUSD;

    assertApproxEqAbs(oracleValueUSD, expectedPositionValueUSD, 328);

    if (DEBUG) {
      emit log_named_decimal_uint("amount0 (USDT)", amount0, 18);
      emit log_named_decimal_uint("amount1 (WBNB)", amount1, 18);
      emit log_named_decimal_uint("usdtValue     ", usdtValueUSD, 18);
      emit log_named_decimal_uint("wbnbValue     ", wbnbValueUSD, 18);
      emit log_named_decimal_uint("expectedValue ", expectedPositionValueUSD, 18);
      emit log_named_decimal_uint("oracleValueUSD", oracleValueUSD, 18);
      emit log_named_uint("deltaAbs      ", stdMath.delta(oracleValueUSD, expectedPositionValueUSD));
      emit log_named_decimal_uint("deltaRel      ", stdMath.percentDelta(oracleValueUSD, expectedPositionValueUSD), 16);
    }
  }

  function testCorrectness_GetPositionValue_NonE18TokenPool() public {
    vm.startPrank(ALICE);
    (uint256 tokenId,, uint256 amount0, uint256 amount1) = pancakeV3PositionManager.mint(
      ICommonV3PositionManager.MintParams({
        token0: pancakeV3DOGEWBNBPool.token0(),
        token1: pancakeV3DOGEWBNBPool.token1(),
        fee: pancakeV3DOGEWBNBPool.fee(),
        tickLower: 100000,
        tickUpper: 200000,
        amount0Desired: 100e8,
        amount1Desired: 100 ether,
        amount0Min: 0,
        amount1Min: 0,
        recipient: address(this),
        deadline: block.timestamp
      })
    );
    vm.stopPrank();

    uint256 oracleValueUSD = liquidityOracle.getPositionValueUSD(address(pancakeV3DOGEWBNBPool), tokenId);

    (, int256 dogePrice,,,) = dogeFeed.latestRoundData();
    uint256 dogeValueUSD = normalizeToE18(amount0, doge.decimals()) * uint256(dogePrice) / (10 ** dogeFeed.decimals());
    (, int256 wbnbPrice,,,) = wbnbFeed.latestRoundData();
    uint256 wbnbValueUSD = amount1 * uint256(wbnbPrice) / (10 ** wbnbFeed.decimals());
    uint256 expectedPositionValueUSD = dogeValueUSD + wbnbValueUSD;

    assertApproxEqAbs(oracleValueUSD, expectedPositionValueUSD, 878738326);

    if (DEBUG) {
      emit log_named_decimal_uint("amount0 (DOGE)", amount0, 8);
      emit log_named_decimal_uint("amount1 (WBNB)", amount1, 18);
      emit log_named_decimal_uint("dogeValue     ", dogeValueUSD, 18);
      emit log_named_decimal_uint("wbnbValue     ", wbnbValueUSD, 18);
      emit log_named_decimal_uint("expectedValue ", expectedPositionValueUSD, 18);
      emit log_named_decimal_uint("oracleValueUSD", oracleValueUSD, 18);
      emit log_named_uint("deltaAbs      ", stdMath.delta(oracleValueUSD, expectedPositionValueUSD));
      emit log_named_decimal_uint("deltaRel      ", stdMath.percentDelta(oracleValueUSD, expectedPositionValueUSD), 16);
    }
  }

  function testRevert_GetPositionValue_PriceTooOld_Token0() public {
    (uint256 tokenId,,) = _mintUSDTWBNB();
    // Mock price feeds to return updateAt 0
    uint256 updatedAt = 0;
    vm.mockCall(
      address(usdtFeed),
      abi.encodeWithSelector(IChainlinkAggregator.latestRoundData.selector),
      abi.encode(0, 0, 0, updatedAt, 0)
    );
    vm.expectRevert(CommonV3LiquidityOracle.CommonV3LiquidityOracle_PriceTooOld.selector);
    liquidityOracle.getPositionValueUSD(address(pancakeV3USDTWBNBPool), tokenId);
  }

  function testRevert_GetPositionValue_PriceTooOld_Token1() public {
    (uint256 tokenId,,) = _mintUSDTWBNB();
    // Mock price feeds to return updateAt 0
    uint256 updatedAt = 0;
    vm.mockCall(
      address(wbnbFeed),
      abi.encodeWithSelector(IChainlinkAggregator.latestRoundData.selector),
      abi.encode(0, 0, 0, updatedAt, 0)
    );
    vm.expectRevert(CommonV3LiquidityOracle.CommonV3LiquidityOracle_PriceTooOld.selector);
    liquidityOracle.getPositionValueUSD(address(pancakeV3USDTWBNBPool), tokenId);
  }

  function testRevert_GetPositionValue_OraclePriceMoreThanPool_DueToToken0() public {
    (uint256 tokenId,,) = _mintUSDTWBNB();

    (, int256 answer,,,) = usdtFeed.latestRoundData();
    vm.mockCall(
      address(usdtFeed),
      abi.encodeWithSelector(IChainlinkAggregator.latestRoundData.selector),
      // increase oracle price of token0 to make oracle price of token0 / token1 higher
      abi.encode(0, answer * 2, 0, block.timestamp, 0)
    );
    vm.expectRevert(CommonV3LiquidityOracle.CommonV3LiquidityOracle_OraclePriceTooHigh.selector);
    liquidityOracle.getPositionValueUSD(address(pancakeV3USDTWBNBPool), tokenId);
  }

  function testRevert_GetPositionValue_OraclePriceLessThanPool_DueToToken0() public {
    (uint256 tokenId,,) = _mintUSDTWBNB();

    (, int256 answer,,,) = usdtFeed.latestRoundData();
    vm.mockCall(
      address(usdtFeed),
      abi.encodeWithSelector(IChainlinkAggregator.latestRoundData.selector),
      // lower oracle price of token0 to make oracle price of token0 / token1 lower
      abi.encode(0, answer / 2, 0, block.timestamp, 0)
    );
    vm.expectRevert(CommonV3LiquidityOracle.CommonV3LiquidityOracle_OraclePriceTooLow.selector);
    liquidityOracle.getPositionValueUSD(address(pancakeV3USDTWBNBPool), tokenId);
  }

  function testRevert_GetPositionValue_OraclePriceMoreThanPool_DueToToken1() public {
    (uint256 tokenId,,) = _mintUSDTWBNB();

    (, int256 answer,,,) = wbnbFeed.latestRoundData();
    vm.mockCall(
      address(wbnbFeed),
      abi.encodeWithSelector(IChainlinkAggregator.latestRoundData.selector),
      // lower oracle price of token1 to make oracle price of token0 / token1 higher
      abi.encode(0, answer / 2, 0, block.timestamp, 0)
    );
    vm.expectRevert(CommonV3LiquidityOracle.CommonV3LiquidityOracle_OraclePriceTooHigh.selector);
    liquidityOracle.getPositionValueUSD(address(pancakeV3USDTWBNBPool), tokenId);
  }

  function testRevert_GetPositionValue_OraclePriceLessThanPool_DueToToken1() public {
    (uint256 tokenId,,) = _mintUSDTWBNB();

    (, int256 answer,,,) = wbnbFeed.latestRoundData();
    vm.mockCall(
      address(wbnbFeed),
      abi.encodeWithSelector(IChainlinkAggregator.latestRoundData.selector),
      // increase oracle price of token1 to make oracle price of token0 / token1 lower
      abi.encode(0, answer * 2, 0, block.timestamp, 0)
    );
    vm.expectRevert(CommonV3LiquidityOracle.CommonV3LiquidityOracle_OraclePriceTooLow.selector);
    liquidityOracle.getPositionValueUSD(address(pancakeV3USDTWBNBPool), tokenId);
  }
}
