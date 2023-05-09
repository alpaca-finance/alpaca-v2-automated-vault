// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/access/Ownable2StepUpgradeable.sol";
import { SafeCastUpgradeable } from "@openzeppelin-upgradeable/utils/math/SafeCastUpgradeable.sol";
import { MathUpgradeable } from "@openzeppelin-upgradeable/utils/math/MathUpgradeable.sol";

// interfaces
import { ICommonV3PositionManager } from "src/interfaces/ICommonV3PositionManager.sol";
import { ICommonV3Pool } from "src/interfaces/ICommonV3Pool.sol";
import { IChainlinkAggregator } from "src/interfaces/IChainlinkAggregator.sol";

// libraries
import { LibFullMath } from "src/libraries/LibFullMath.sol";
import { LibTickMath } from "src/libraries/LibTickMath.sol";
import { LibLiquidityAmounts } from "src/libraries/LibLiquidityAmounts.sol";

contract CommonV3LiquidityOracle is Ownable2StepUpgradeable {
  using SafeCastUpgradeable for uint256;
  using SafeCastUpgradeable for int256;

  ICommonV3PositionManager public positionManager;
  mapping(address => IChainlinkAggregator) public priceFeedOf;
  uint16 public maxPriceAge;
  uint16 public maxPriceDiff;

  event SetMaxPriceAge(uint16 prevMaxPriceAge, uint16 maxPriceAge);
  event SetMaxPriceDiff(uint16 prevMaxPriceDiff, uint16 maxPriceDiff);
  event SetPriceFeedOf(address indexed token, IChainlinkAggregator prevPriceFeed, IChainlinkAggregator priceFeed);

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
  /// @param token Token address.
  /// @param priceFeed Price feed address.
  function setPriceFeedOf(address token, IChainlinkAggregator priceFeed) external onlyOwner {
    emit SetPriceFeedOf(token, priceFeedOf[token], priceFeed);
    priceFeedOf[token] = priceFeed;
  }

  /// @notice Set max price age.
  /// @param _maxPriceAge Max price age in seconds.
  function setMaxPriceAge(uint16 _maxPriceAge) external onlyOwner {
    emit SetMaxPriceAge(maxPriceAge, _maxPriceAge);
    maxPriceAge = _maxPriceAge;
  }

  /// @notice Set max price diff.
  /// @param _maxPriceDiff Max price diff in 1e18.
  function setMaxPriceDiff(uint16 _maxPriceDiff) external onlyOwner {
    emit SetMaxPriceDiff(maxPriceDiff, _maxPriceDiff);
    maxPriceDiff = _maxPriceDiff;
  }

  /// @notice Return price in uint256. Revert if price too old or negative.
  /// @param _token Token address.
  function _safeGetPrice(address _token) internal view returns (uint256 _price, uint8 _decimals) {
    // SLOAD
    IChainlinkAggregator _priceFeed = priceFeedOf[_token];
    (, int256 __price,, uint256 _updatedAt,) = priceFeedOf[_token].latestRoundData();
    require(block.timestamp - _updatedAt <= maxPriceAge, "price old");
    return (__price.toUint256(), _priceFeed.decimals());
  }

  /// @notice Return decoded SqrtPriceX96 in 18 decimals.
  /// @dev 1e18 as decoded price is to be used in calculations.
  function _decodeSqrtPriceX96(uint160 _sqrtPriceX96) internal pure returns (uint256 _price) {
    uint256 numerator1 = uint256(_sqrtPriceX96) * uint256(_sqrtPriceX96);
    uint256 numerator2 = 10 ** 18;
    return LibFullMath.mulDiv(numerator1, numerator2, 1 << 192);
  }

  /// @notice Return encoded SqrtPriceX96.
  /// @param _price Price in 8 decimals.
  /// @dev 1e8 as a param due to price is most likely from Chainlink which is 8 decimals.
  /// @dev 1e4 due to sqrt price half 1e8.
  function _encodeSqrtPriceX96(uint256 _price) internal pure returns (uint160 _sqrtPriceX96) {
    uint256 intermediate = LibFullMath.mulDiv(MathUpgradeable.sqrt(_price), 2 ** 96, 1e4);
    return intermediate.toUint160();
  }

  /// @notice Return liquidity value in token1.
  /// @dev 1e18 as decoded price is to be used in calculations.
  /// @param _liquidity Liquidity amount.
  /// @param _sqrtPriceX96 SqrtPriceX96.
  /// @param _tickLower Tick lower.
  /// @param _tickUpper Tick upper.
  function _calcLiquidityToken1(uint128 _liquidity, uint160 _sqrtPriceX96, int24 _tickLower, int24 _tickUpper)
    internal
    pure
    returns (uint256 _valueInToken1)
  {
    (uint256 _amount0, uint256 _amount1) = LibLiquidityAmounts.getAmountsForLiquidity(
      _sqrtPriceX96, LibTickMath.getSqrtRatioAtTick(_tickLower), LibTickMath.getSqrtRatioAtTick(_tickUpper), _liquidity
    );
    return LibFullMath.mulDiv(_amount0, _decodeSqrtPriceX96(_sqrtPriceX96), 1e18) + _amount1;
  }

  /// @notice Get USD value of a position.
  /// @param _pool Pool address.
  /// @param _tokenId Token ID.
  function calcLiquidityUsd(ICommonV3Pool _pool, uint256 _tokenId) public view returns (uint256 _valueInUsd) {
    // Load position data
    (,, address _token0, address _token1,, int24 _tickLower, int24 _tickUpper, uint128 _liquidity,,,,) =
      positionManager.positions(_tokenId);

    // Get prices from oracle
    (uint256 _token0Price, uint8 _token0PriceDecimals) = _safeGetPrice(_token0);
    (uint256 _token1Price, uint8 _token1PriceDecimals) = _safeGetPrice(_token1);
    uint160 _oracleSqrtPriceX96 = _encodeSqrtPriceX96(
      LibFullMath.mulDiv(_token0Price, 10 ** _token1PriceDecimals, _token1Price) * 1e8 / _token0PriceDecimals
    );

    // Get sqrtPriceX96 from pool
    (uint160 _poolSqrtPriceX96,,,,,,) = _pool.slot0();

    // Calculate liquidity value by poolSqrtPriceX96
    uint256 _poolValueToken1 = _calcLiquidityToken1(_liquidity, _poolSqrtPriceX96, _tickLower, _tickUpper);
    // Calculate liquidity value by oracleSqrtPriceX96
    uint256 _oracleValueToken1 = _calcLiquidityToken1(_liquidity, _oracleSqrtPriceX96, _tickLower, _tickUpper);

    require(_poolValueToken1 * 10000 <= _oracleValueToken1 * maxPriceDiff, "TH");
    require(_poolValueToken1 * maxPriceDiff >= _oracleValueToken1 * 10000, "TL");

    // _poolValueToken1 * _token1OraclePrice
    return LibFullMath.mulDiv(_poolValueToken1, _token1Price, 1e18);
  }
}
