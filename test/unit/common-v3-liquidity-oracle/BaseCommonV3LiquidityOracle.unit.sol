// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { ERC20 } from "@solmate/tokens/ERC20.sol";

import "test/base/BaseForkTest.sol";

// contracts
import { CommonV3LiquidityOracle } from "src/CommonV3LiquidityOracle.sol";

// interfaces
import { IAutomatedVaultManager } from "src/interfaces/IAutomatedVaultManager.sol";
import { ICommonV3PositionManager } from "src/interfaces/ICommonV3PositionManager.sol";

abstract contract BaseCommonV3LiquidityOracleUnitForkTest is BaseForkTest {
  uint16 MAX_PRICE_AGE = 60 * 60;
  uint16 MAX_PRICE_DIFF = 10_500;

  CommonV3LiquidityOracle liquidityOracle;

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
    liquidityOracle.setPriceFeedOf(address(doge), address(dogeFeed));
    vm.stopPrank();

    deal(address(wbnb), ALICE, 100 ether);
    deal(address(usdt), ALICE, 100 ether);
    deal(address(doge), ALICE, 100 ether);

    vm.startPrank(ALICE);
    wbnb.approve(address(pancakeV3PositionManager), type(uint256).max);
    usdt.approve(address(pancakeV3PositionManager), type(uint256).max);
    doge.approve(address(pancakeV3PositionManager), type(uint256).max);
    vm.stopPrank();
  }

  function _mintUSDTWBNB() internal returns (uint256 tokenId, uint256 amount0, uint256 amount1) {
    vm.startPrank(ALICE);
    (tokenId,, amount0, amount1) = pancakeV3PositionManager.mint(
      ICommonV3PositionManager.MintParams({
        token0: pancakeV3USDTWBNBPool.token0(),
        token1: pancakeV3USDTWBNBPool.token1(),
        fee: pancakeV3USDTWBNBPool.fee(),
        tickLower: -58000,
        tickUpper: -57750,
        amount0Desired: 100 ether,
        amount1Desired: 100 ether,
        amount0Min: 0,
        amount1Min: 0,
        recipient: address(this),
        deadline: block.timestamp
      })
    );
    vm.stopPrank();
  }
}
