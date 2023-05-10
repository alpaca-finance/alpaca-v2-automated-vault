// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/access/Ownable2StepUpgradeable.sol";
import { SafeCastUpgradeable } from "@openzeppelin-upgradeable/utils/math/SafeCastUpgradeable.sol";
import { MathUpgradeable } from "@openzeppelin-upgradeable/utils/math/MathUpgradeable.sol";

// interfaces
import { IERC20 } from "src/interfaces/IERC20.sol";
import { ICommonV3PositionManager } from "src/interfaces/ICommonV3PositionManager.sol";
import { ICommonV3Pool } from "src/interfaces/ICommonV3Pool.sol";
import { IChainlinkAggregator } from "src/interfaces/IChainlinkAggregator.sol";

// libraries
import { LibFullMath } from "src/libraries/LibFullMath.sol";
import { LibTickMath } from "src/libraries/LibTickMath.sol";
import { LibLiquidityAmounts } from "src/libraries/LibLiquidityAmounts.sol";
import { LibSqrtPriceX96 } from "src/libraries/LibSqrtPriceX96.sol";

contract CommonV3LiquidityOracle is Ownable2StepUpgradeable {
  using SafeCastUpgradeable for uint256;
  using SafeCastUpgradeable for int256;

  error CommonV3LiquidityOracle_InvalidParams();
  error CommonV3LiquidityOracle_PriceTooOld();

  // packed slot
  ICommonV3PositionManager public positionManager;
  uint16 public maxPriceAge;
  uint16 public maxPriceDiff;

  mapping(address => IChainlinkAggregator) public priceFeedOf;

  event SetMaxPriceAge(uint16 prevMaxPriceAge, uint16 maxPriceAge);
  event SetMaxPriceDiff(uint16 prevMaxPriceDiff, uint16 maxPriceDiff);
  event SetPriceFeedOf(address indexed token, address prevPriceFeed, address priceFeed);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(ICommonV3PositionManager _positionManager, uint16 _maxPriceAge, uint16 _maxPriceDiff)
    external
    initializer
  {
    Ownable2StepUpgradeable.__Ownable2Step_init();

    positionManager = _positionManager;
    maxPriceAge = _maxPriceAge;
    maxPriceDiff = _maxPriceDiff;
  }

  /// @notice Set price feed of a token.
  /// @param _token Token address.
  /// @param _newPriceFeed New price feed address.
  function setPriceFeedOf(address _token, address _newPriceFeed) external onlyOwner {
    // Sanity check
    (, int256 _answer,,,) = IChainlinkAggregator(_newPriceFeed).latestRoundData();
    if (_answer == 0) {
      revert CommonV3LiquidityOracle_InvalidParams();
    }
    emit SetPriceFeedOf(_token, address(priceFeedOf[_token]), _newPriceFeed);
    priceFeedOf[_token] = IChainlinkAggregator(_newPriceFeed);
  }

  /// @notice Set max price age.
  /// @param _newMaxPriceAge Max price age in seconds.
  function setMaxPriceAge(uint16 _newMaxPriceAge) external onlyOwner {
    emit SetMaxPriceAge(maxPriceAge, _newMaxPriceAge);
    maxPriceAge = _newMaxPriceAge;
  }

  /// @notice Set max price diff.
  /// @param _newMaxPriceDiff Max price diff in bps.
  function setMaxPriceDiff(uint16 _newMaxPriceDiff) external onlyOwner {
    emit SetMaxPriceDiff(maxPriceDiff, _newMaxPriceDiff);
    maxPriceDiff = _newMaxPriceDiff;
  }

  /// @notice Fetch token price from price feed. Revert if price too old or negative.
  /// @param _token Token address.
  /// @return _price Price of the token in 18 decimals.
  function _safeGetTokenPriceE18(address _token) internal view returns (uint256 _price) {
    // SLOAD
    IChainlinkAggregator _priceFeed = priceFeedOf[_token];
    (, int256 _answer,, uint256 _updatedAt,) = _priceFeed.latestRoundData();
    // Safe to use unchecked since `block.timestamp` will at least equal to `_updatedAt` in the same block
    unchecked {
      if (block.timestamp - _updatedAt > maxPriceAge) {
        revert CommonV3LiquidityOracle_PriceTooOld();
      }
    }
    // Normalized to 18 decimals
    return _answer.toUint256() * (10 ** (18 - _priceFeed.decimals()));
  }

  // /// @notice Return liquidity value in token1.
  // /// @param _liquidity Liquidity amount.
  // /// @param _sqrtPriceX96 SqrtPriceX96.
  // /// @param _tickLower Tick lower.
  // /// @param _tickUpper Tick upper.
  // function _calcLiquidityToken1(uint128 _liquidity, uint160 _sqrtPriceX96, int24 _tickLower, int24 _tickUpper)
  //   internal
  //   pure
  //   returns (uint256 _valueInToken1)
  // {
  //   (uint256 _amount0, uint256 _amount1) = LibLiquidityAmounts.getAmountsForLiquidity(
  //     _sqrtPriceX96, LibTickMath.getSqrtRatioAtTick(_tickLower), LibTickMath.getSqrtRatioAtTick(_tickUpper), _liquidity
  //   );
  //   // 1e18 as decoded price is to be used in calculations.
  //   return LibFullMath.mulDiv(_amount0, _decodeSqrtPriceX96(_sqrtPriceX96), 1e18) + _amount1;
  // }

  // /// @notice Get USD value of a position.
  // /// @param _pool Pool address.
  // /// @param _tokenId Token ID.
  // function calcLiquidityUsd(address _pool, uint256 _tokenId) external view returns (uint256 _valueInUsd) {
  //   // Load position data
  //   (,, address _token0, address _token1,, int24 _tickLower, int24 _tickUpper, uint128 _liquidity,,,,) =
  //     positionManager.positions(_tokenId);

  //   // Get sqrtPriceX96 from pool
  //   (uint160 _poolSqrtPriceX96,,,,,,) = ICommonV3Pool(_pool).slot0();
  //   // Calculate token1 amount that position has according to pool's sqrtPriceX96
  //   uint256 _poolAmountToken1 = _calcLiquidityToken1(_liquidity, _poolSqrtPriceX96, _tickLower, _tickUpper);

  //   // Get prices from oracle
  //   (uint256 _token0Price, uint8 _token0PriceDecimals) = _safeGetTokenPrice(_token0);
  //   (uint256 _token1Price, uint8 _token1PriceDecimals) = _safeGetTokenPrice(_token1);
  //   // Convert oracle price into sqrtPriceX96
  //   // 1e8 to convert price to 8 decimals for `_encodeSqrtPriceX96`
  //   uint160 _oracleSqrtPriceX96 =
  //     _encodeSqrtPriceX96(_token0Price * (10 ** _token1PriceDecimals) * 1e8 / (_token1Price * _token0PriceDecimals));
  //   // Calculate token1 amount that position has according to oracle's sqrtPriceX96
  //   uint256 _oracleAmountToken1 = _calcLiquidityToken1(_liquidity, _oracleSqrtPriceX96, _tickLower, _tickUpper);

  //   // Check price deviation
  //   require(_poolAmountToken1 * 10000 <= _oracleAmountToken1 * maxPriceDiff, "TH");
  //   require(_poolAmountToken1 * maxPriceDiff >= _oracleAmountToken1 * 10000, "TL");

  //   // _poolAmountToken1 * _token1OraclePrice
  //   return LibFullMath.mulDiv(_poolAmountToken1, _token1Price, 1e18);
  // }

  function getPositionValueUSD(address _pool, uint256 _tokenId) external view returns (uint256 _valueUSD) {
    // Prepare
    // Load position data
    (,, address _token0, address _token1,, int24 _tickLower, int24 _tickUpper, uint128 _liquidity,,,,) =
      positionManager.positions(_tokenId);
    // Tokens decimals
    uint8 _token0Decimals = IERC20(_token0).decimals();
    uint8 _token1Decimals = IERC20(_token1).decimals();
    // Convert tick into sqrtPriceX96
    uint160 _tickLowerSqrtPriceX96 = LibTickMath.getSqrtRatioAtTick(_tickLower);
    uint160 _tickUpperSqrtPriceX96 = LibTickMath.getSqrtRatioAtTick(_tickUpper);

    uint256 _poolAmount1;
    {
      // Get sqrtPriceX96 from pool
      (uint160 _poolSqrtPriceX96,,,,,,) = ICommonV3Pool(_pool).slot0();
      // Calculate amounts with pool's sqrtPriceX96
      uint256 _poolAmount0;
      (_poolAmount0, _poolAmount1) = LibLiquidityAmounts.getAmountsForLiquidity(
        _poolSqrtPriceX96, _tickLowerSqrtPriceX96, _tickUpperSqrtPriceX96, _liquidity
      );
      _poolAmount1 += LibFullMath.mulDiv(
        _poolAmount0, LibSqrtPriceX96.decodeSqrtPriceX96(_poolSqrtPriceX96, _token0Decimals, _token1Decimals), 1e18
      );
    }

    uint256 _oracleAmount1;
    uint256 _token1OraclePrice;
    {
      // Get prices from oracle
      uint256 _token0OraclePrice = _safeGetTokenPriceE18(_token0);
      _token1OraclePrice = _safeGetTokenPriceE18(_token1);
      // Calculate amounts with oracle's estimated sqrtPriceX96
      uint256 _oraclePriceE18 = _token0OraclePrice * 1e18 / _token1OraclePrice;
      uint160 _oracleSqrtPriceX96 =
        LibSqrtPriceX96.encodeSqrtPriceX96(_oraclePriceE18, _token0Decimals, _token1Decimals);
      uint256 _oracleAmount0;
      (_oracleAmount0, _oracleAmount1) = LibLiquidityAmounts.getAmountsForLiquidity(
        _oracleSqrtPriceX96, _tickLowerSqrtPriceX96, _tickUpperSqrtPriceX96, _liquidity
      );
      _oracleAmount1 += LibFullMath.mulDiv(_oracleAmount0, _oraclePriceE18, 1e18);
    }

    // Check deviation
    require(_poolAmount1 * 10000 <= _oracleAmount1 * maxPriceDiff, "TH");
    require(_poolAmount1 * maxPriceDiff >= _oracleAmount1 * 10000, "TL");

    return LibFullMath.mulDiv(_oracleAmount1, _token1OraclePrice, 1e18);
  }
}
