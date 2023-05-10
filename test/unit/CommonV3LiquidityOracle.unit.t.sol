// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { ERC20 } from "@solmate/tokens/ERC20.sol";

import "test/base/BaseForkTest.sol";

// contracts
import { CommonV3LiquidityOracle } from "src/CommonV3LiquidityOracle.sol";

// interfaces
import { IAutomatedVaultManager } from "src/interfaces/IAutomatedVaultManager.sol";
import { ICommonV3PositionManager } from "src/interfaces/ICommonV3PositionManager.sol";
import { IChainlinkAggregator } from "src/interfaces/IChainlinkAggregator.sol";

contract CommonV3LiquidityOracleUnitForkTest is BaseForkTest {
  bool DEBUG = true;

  uint16 MAX_PRICE_AGE = 60 * 60;
  uint16 MAX_PRICE_DIFF = 10_500;

  CommonV3LiquidityOracle liquidityOracle;

  IChainlinkAggregator wbnbFeed = IChainlinkAggregator(0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE);
  IChainlinkAggregator usdtFeed = IChainlinkAggregator(0xB97Ad0E74fa7d920791E90258A6E2085088b4320);

  int24 internal constant TICK_LOWER = -58000;
  int24 internal constant TICK_UPPER = -57750;
  ERC20 token0;
  ERC20 token1;
  uint24 poolFee;

  function setUp() public override {
    super.setUp();

    vm.createSelectFork("bsc_mainnet", 27_515_914);

    vm.startPrank(DEPLOYER);
    liquidityOracle = CommonV3LiquidityOracle(
      deployUpgradeable(
        "CommonV3LiquidityOracle",
        abi.encodeWithSignature(
          "initialize(address,uint16,uint16)", address(pancakeV3PositionManager), MAX_PRICE_AGE, MAX_PRICE_DIFF
        )
      )
    );
    liquidityOracle.setPriceFeedOf(address(wbnb), address(wbnbFeed));
    liquidityOracle.setPriceFeedOf(address(usdt), address(usdtFeed));
    vm.stopPrank();

    token0 = ERC20(pancakeV3WBNBUSDTPool.token0());
    token1 = ERC20(pancakeV3WBNBUSDTPool.token1());
    poolFee = pancakeV3WBNBUSDTPool.fee();

    deal(address(wbnb), ALICE, 100 ether);
    deal(address(usdt), ALICE, 100 ether);

    vm.startPrank(ALICE);
    wbnb.approve(address(pancakeV3PositionManager), type(uint256).max);
    usdt.approve(address(pancakeV3PositionManager), type(uint256).max);
    vm.stopPrank();
  }

  function testCorrectness_GetPositionValue() public {
    vm.prank(ALICE);
    (uint256 tokenId,, uint256 amount0, uint256 amount1) = pancakeV3PositionManager.mint(
      ICommonV3PositionManager.MintParams({
        token0: address(token0),
        token1: address(token1),
        fee: poolFee,
        tickLower: TICK_LOWER,
        tickUpper: TICK_UPPER,
        amount0Desired: 100 ether,
        amount1Desired: 100 ether,
        amount0Min: 0,
        amount1Min: 0,
        recipient: address(this),
        deadline: block.timestamp
      })
    );

    uint256 oracleValueUSD = liquidityOracle.getPositionValueUSD(address(pancakeV3WBNBUSDTPool), tokenId);

    (, int256 usdtPrice,,,) = usdtFeed.latestRoundData();
    uint256 usdtValueUSD = amount0 * uint256(usdtPrice) / (10 ** usdtFeed.decimals());
    (, int256 wbnbPrice,,,) = wbnbFeed.latestRoundData();
    uint256 wbnbValueUSD = amount1 * uint256(wbnbPrice) / (10 ** wbnbFeed.decimals());

    assertApproxEqRel(oracleValueUSD, usdtValueUSD + wbnbValueUSD, 1e13); // within 0.001% diff

    if (DEBUG) {
      emit log_named_decimal_uint("amount0 (USDT)", amount0, 18);
      emit log_named_decimal_uint("amount1 (WBNB)", amount1, 18);
      emit log_named_decimal_uint("usdtValue     ", usdtValueUSD, 18);
      emit log_named_decimal_uint("wbnbValue     ", wbnbValueUSD, 18);
      emit log_named_decimal_uint("expectedValue ", usdtValueUSD + wbnbValueUSD, 18);
      emit log_named_decimal_uint("oracleValueUSD", oracleValueUSD, 18);
    }
  }

  // TODO: setter test

  function testRevert_NotOwnerCallSetter() public {
    vm.startPrank(ALICE);

    vm.expectRevert("Ownable: caller is not the owner");
    liquidityOracle.setMaxPriceAge(100);

    vm.expectRevert("Ownable: caller is not the owner");
    liquidityOracle.setMaxPriceDiff(100);

    vm.expectRevert("Ownable: caller is not the owner");
    liquidityOracle.setPriceFeedOf(address(0), address(0));

    vm.stopPrank();
  }
}
