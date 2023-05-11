// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./BaseCommonV3LiquidityOracle.unit.sol";

contract CommonV3LiquidityOracle_GetPositionValueUnitForkTest is BaseCommonV3LiquidityOracleUnitForkTest {
  function testCorrectness_OwnerSetMaxPriceAge_ShouldWork() public {
    vm.prank(DEPLOYER);
    liquidityOracle.setMaxPriceAge(100);

    assertEq(liquidityOracle.maxPriceAge(), 100);
  }

  function testCorrectness_OwnerSetMaxPriceDiff_ShouldWork() public {
    vm.prank(DEPLOYER);
    liquidityOracle.setMaxPriceDiff(10_500);

    assertEq(liquidityOracle.maxPriceDiff(), 10_500);
  }

  function testCorrectness_OwnerSetPriceFeed_ShouldWork() public {
    vm.startPrank(DEPLOYER);
    liquidityOracle.setPriceFeedOf(address(wbnb), address(wbnbFeed));

    assertEq(address(liquidityOracle.priceFeedOf(address(wbnb))), address(wbnbFeed));
  }

  function testRevert_OwnerSetNonExistentPriceFeed() public {
    vm.expectRevert();
    liquidityOracle.setPriceFeedOf(address(wbnb), address(0));
  }

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
