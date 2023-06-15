// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// interfaces
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { IZapV3 } from "src/interfaces/IZapV3.sol";
import { ICommonV3Pool } from "src/interfaces/ICommonV3Pool.sol";
import { ICommonV3PositionManager } from "src/interfaces/ICommonV3PositionManager.sol";
import { IPancakeV3Router } from "src/interfaces/pancake-v3/IPancakeV3Router.sol";
import { IPancakeV3MasterChef } from "src/interfaces/pancake-v3/IPancakeV3MasterChef.sol";

// libraries
import { LibTickMath } from "src/libraries/LibTickMath.sol";
import { MAX_BPS } from "src/libraries/Constants.sol";

contract PancakeV3Worker is Initializable, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable {
  using SafeTransferLib for ERC20;

  error PancakeV3Worker_Unauthorized();
  error PancakeV3Worker_InvalidTask();
  error PancakeV3Worker_PositionExist();
  error PancakeV3Worker_PositionNotExist();
  error PancakeV3Worker_InvalidParams();

  // pool info
  ERC20 public token0;
  ERC20 public token1;
  // packed slot
  ICommonV3Pool public pool;
  uint24 public poolFee;
  int24 public posTickLower;
  int24 public posTickUpper;

  // packed slot for reinvest
  address public performanceFeeBucket;
  uint16 public performanceFeeBps;
  uint40 public lastHarvest;

  IZapV3 public zapV3;

  // pancake config
  ERC20 public cake;
  ICommonV3PositionManager public nftPositionManager;
  IPancakeV3Router public router;
  IPancakeV3MasterChef public masterChef;

  uint256 public nftTokenId;

  /// Authorization
  AutomatedVaultManager public vaultManager;

  /// Modifier
  modifier onlyExecutorInScope() {
    if (msg.sender != vaultManager.EXECUTOR_IN_SCOPE()) {
      revert PancakeV3Worker_Unauthorized();
    }
    _;
  }

  /// Events
  event LogIncreaseLiquidity(uint256 _tokenId, uint256 _amount0, uint256 _amount1, uint128 _liquidity);
  event LogCollectPerformanceFee(
    address indexed _token, uint256 _earned, uint16 _performanceFeeBps, uint256 _performanceFee
  );
  event LogDecreaseLiquidity(uint256 tokenId, uint256 amount0out, uint256 amount1out, uint128 liquidityOut);
  event LogOpenPosition(
    uint256 indexed _tokenId, address _caller, int24 _tickLower, int24 _tickUpper, uint256 _amount0, uint256 _amount1
  );
  event LogIncreasePosition(
    uint256 indexed _tokenId, address _caller, int24 _tickLower, int24 _tickUpper, uint256 _amount0, uint256 _amount1
  );
  event LogClosePosition(
    uint256 indexed _tokenId, address _caller, uint256 _amount0Out, uint256 _amount1Out, uint128 _liquidityOut
  );
  event LogDecreasePosition(
    uint256 indexed _tokenId, address _caller, uint256 _amount0Out, uint256 _amount1Out, uint128 _liquidityOut
  );
  event LogTransferToExecutor(address indexed _token, address _to, uint256 _amount);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  struct ConstructorParams {
    AutomatedVaultManager vaultManager;
    ICommonV3PositionManager positionManager;
    ICommonV3Pool pool;
    IPancakeV3Router router;
    IPancakeV3MasterChef masterChef;
    IZapV3 zapV3;
    address performanceFeeBucket;
    uint16 performanceFeeBps;
  }

  function initialize(ConstructorParams calldata _params) external initializer {
    Ownable2StepUpgradeable.__Ownable2Step_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
    // TODO: validate _params
    vaultManager = _params.vaultManager;

    nftPositionManager = _params.positionManager;
    pool = _params.pool;
    router = _params.router;
    masterChef = _params.masterChef;
    poolFee = _params.pool.fee();
    token0 = ERC20(pool.token0());
    token1 = ERC20(pool.token1());
    cake = ERC20(masterChef.CAKE());

    zapV3 = _params.zapV3;

    performanceFeeBps = _params.performanceFeeBps;
    performanceFeeBucket = _params.performanceFeeBucket;
  }

  /// @dev Can't open position for pool that doesn't have CAKE reward (masterChef pid == 0).
  // TODO: check sufficient balance for amountIn
  function openPosition(int24 _tickLower, int24 _tickUpper, uint256 _amountIn0, uint256 _amountIn1)
    external
    nonReentrant
    onlyExecutorInScope
  {
    // Can't open position if already exist. Use `increasePosition` instead.
    if (nftTokenId != 0) {
      revert PancakeV3Worker_PositionExist();
    }

    // SLOAD
    ERC20 _token0 = token0;
    ERC20 _token1 = token1;

    // Prepare optimal tokens for adding liquidity
    (uint256 _amount0Desired, uint256 _amount1Desired) = _prepareOptimalTokensForIncrease(
      address(_token0), address(_token1), _tickLower, _tickUpper, _amountIn0, _amountIn1
    );

    // SLOAD
    ICommonV3PositionManager _nftPositionManager = nftPositionManager;
    // Mint new position and stake it with masterchef
    _token0.safeApprove(address(_nftPositionManager), _amount0Desired);
    _token1.safeApprove(address(_nftPositionManager), _amount1Desired);
    (uint256 _nftTokenId,, uint256 _amount0, uint256 _amount1) = _nftPositionManager.mint(
      ICommonV3PositionManager.MintParams({
        token0: address(_token0),
        token1: address(_token1),
        fee: poolFee,
        tickLower: _tickLower,
        tickUpper: _tickUpper,
        amount0Desired: _amount0Desired,
        amount1Desired: _amount1Desired,
        amount0Min: 0,
        amount1Min: 0,
        recipient: address(this),
        deadline: block.timestamp
      })
    );
    // Stake to PancakeMasterChefV3
    // NOTE: masterChef won't accept transfer from nft that associate with pool that doesn't have masterChef pid
    // aka no CAKE reward
    _nftPositionManager.safeTransferFrom(address(this), address(masterChef), _nftTokenId);
    // Update token id
    nftTokenId = _nftTokenId;

    // Update worker ticks config
    posTickLower = _tickLower;
    posTickUpper = _tickUpper;

    emit LogOpenPosition(_nftTokenId, msg.sender, _tickLower, _tickUpper, _amount0, _amount1);
  }

  function increasePosition(uint256 _amountIn0, uint256 _amountIn1) external nonReentrant onlyExecutorInScope {
    // Can't increase position if position not exist. Use `openPosition` instead.
    if (nftTokenId == 0) {
      revert PancakeV3Worker_PositionNotExist();
    }

    // SLOAD
    ERC20 _token0 = token0;
    ERC20 _token1 = token1;
    int24 _tickLower = posTickLower;
    int24 _tickUpper = posTickUpper;

    // Prepare optimal tokens for adding liquidity
    (uint256 _amount0Desired, uint256 _amount1Desired) = _prepareOptimalTokensForIncrease(
      address(_token0), address(_token1), _tickLower, _tickUpper, _amountIn0, _amountIn1
    );

    // Increase existing position liquidity
    // SLOAD
    IPancakeV3MasterChef _masterChef = masterChef;
    uint256 _nftTokenId = nftTokenId;

    _token0.safeApprove(address(_masterChef), _amount0Desired);
    _token1.safeApprove(address(_masterChef), _amount1Desired);
    (, uint256 _amount0, uint256 _amount1) = _masterChef.increaseLiquidity(
      IPancakeV3MasterChef.IncreaseLiquidityParams({
        tokenId: _nftTokenId,
        amount0Desired: _amount0Desired,
        amount1Desired: _amount1Desired,
        amount0Min: 0,
        amount1Min: 0,
        deadline: block.timestamp
      })
    );

    emit LogIncreasePosition(_nftTokenId, msg.sender, _tickLower, _tickUpper, _amount0, _amount1);
  }

  function _prepareOptimalTokensForIncrease(
    address _token0,
    address _token1,
    int24 _tickLower,
    int24 _tickUpper,
    uint256 _amountIn0,
    uint256 _amountIn1
  ) internal returns (uint256 _amount0Desired, uint256 _amount1Desired) {
    (, int24 _currTick,,,,,) = pool.slot0();
    if (_tickLower <= _currTick && _currTick <= _tickUpper) {
      (_amount0Desired, _amount1Desired) = _prepareOptimalTokensForIncreaseInRange(
        address(_token0), address(_token1), _tickLower, _tickUpper, _amountIn0, _amountIn1
      );
    } else {
      (_amount0Desired, _amount1Desired) = _prepareOptimalTokensForIncreaseOutOfRange(
        address(_token0), address(_token1), _currTick, _tickLower, _tickUpper, _amountIn0, _amountIn1
      );
    }
  }

  function _prepareOptimalTokensForIncreaseInRange(
    address _token0,
    address _token1,
    int24 _tickLower,
    int24 _tickUpper,
    uint256 _amountIn0,
    uint256 _amountIn1
  ) internal returns (uint256 _optimalAmount0, uint256 _optimalAmount1) {
    // Calculate zap in amount and direction.
    (uint256 _amountSwap, uint256 _minAmountOut, bool _zeroForOne) = zapV3.calc(
      IZapV3.CalcParams({
        pool: address(pool),
        amountIn0: _amountIn0,
        amountIn1: _amountIn1,
        tickLower: _tickLower,
        tickUpper: _tickUpper
      })
    );

    // Find out tokenIn and tokenOut
    address _tokenIn;
    address _tokenOut;
    if (_zeroForOne) {
      _tokenIn = address(_token0);
      _tokenOut = address(_token1);
    } else {
      _tokenIn = address(_token1);
      _tokenOut = address(_token0);
    }

    // Swap
    ERC20(_tokenIn).safeApprove(address(router), _amountSwap);
    router.exactInputSingle(
      IPancakeV3Router.ExactInputSingleParams({
        tokenIn: _tokenIn,
        tokenOut: _tokenOut,
        fee: poolFee,
        recipient: address(this),
        amountIn: _amountSwap,
        amountOutMinimum: _minAmountOut,
        sqrtPriceLimitX96: 0
      })
    );

    _optimalAmount0 = ERC20(_token0).balanceOf(address(this));
    _optimalAmount1 = ERC20(_token1).balanceOf(address(this));
  }

  function _prepareOptimalTokensForIncreaseOutOfRange(
    address _token0,
    address _token1,
    int24 _currTick,
    int24 _tickLower,
    int24 _tickUpper,
    uint256 _amountIn0,
    uint256 _amountIn1
  ) internal returns (uint256 _optimalAmount0, uint256 _optimalAmount1) {
    // SLOAD
    int24 _tickSpacing = pool.tickSpacing();
    IPancakeV3Router _router = router;

    // If out of upper range (currTick > tickUpper), we swap token0 for token1
    // and vice versa, to push price closer to range.
    // We only want to swap until price move back in range so
    // we will swap until price hit the first tick within range.
    if (_currTick > _tickUpper) {
      if (_amountIn0 > 0) {
        // zero for one swap
        ERC20(_token0).safeApprove(address(_router), _amountIn0);
        _router.exactInputSingle(
          IPancakeV3Router.ExactInputSingleParams({
            tokenIn: _token0,
            tokenOut: _token1,
            fee: poolFee,
            recipient: address(this),
            amountIn: _amountIn0,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: LibTickMath.getSqrtRatioAtTick(_tickUpper - _tickSpacing - 1)
          })
        );
      }
    } else {
      if (_amountIn1 > 0) {
        // one for zero swap
        ERC20(_token1).safeApprove(address(_router), _amountIn1);
        _router.exactInputSingle(
          IPancakeV3Router.ExactInputSingleParams({
            tokenIn: _token1,
            tokenOut: _token0,
            fee: poolFee,
            recipient: address(this),
            amountIn: _amountIn1,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: LibTickMath.getSqrtRatioAtTick(_tickLower + _tickSpacing + 1)
          })
        );
      }
    }

    // Update optimal amount
    _optimalAmount0 = ERC20(_token0).balanceOf(address(this));
    _optimalAmount1 = ERC20(_token1).balanceOf(address(this));

    // Also prepare in range if tick is back in range after swap
    (, _currTick,,,,,) = pool.slot0();
    if (_tickLower <= _currTick && _currTick <= _tickUpper) {
      return _prepareOptimalTokensForIncreaseInRange(
        _token0, _token1, _tickLower, _tickUpper, _optimalAmount0, _optimalAmount1
      );
    }
  }

  /// @dev Closing position (burning NFT) requires NFT to be empty (no tokens, rewards remain).
  /// Executor should handle claiming rewards before closing position.
  function closePosition() external nonReentrant onlyExecutorInScope {
    uint256 _prevNftTokenId = nftTokenId;
    if (_prevNftTokenId == 0) {
      revert PancakeV3Worker_PositionNotExist();
    }

    // Reset nftTokenId
    nftTokenId = 0;

    IPancakeV3MasterChef _masterChef = masterChef;
    IPancakeV3MasterChef.UserPositionInfo memory _positionInfo = _masterChef.userPositionInfos(_prevNftTokenId);
    (uint256 _amount0, uint256 _amount1) = _decreaseLiquidity(_prevNftTokenId, _masterChef, _positionInfo.liquidity);
    _masterChef.burn(_prevNftTokenId);

    emit LogClosePosition(_prevNftTokenId, msg.sender, _amount0, _amount1, _positionInfo.liquidity);
  }

  function decreasePosition(uint128 _liquidity)
    external
    nonReentrant
    onlyExecutorInScope
    returns (uint256 _amount0, uint256 _amount1)
  {
    uint256 _nftTokenId = nftTokenId;
    if (_nftTokenId == 0) {
      revert PancakeV3Worker_PositionNotExist();
    }
    (_amount0, _amount1) = _decreaseLiquidity(_nftTokenId, masterChef, _liquidity);
    emit LogDecreasePosition(_nftTokenId, msg.sender, _amount0, _amount1, _liquidity);
  }

  function _decreaseLiquidity(uint256 _nftTokenId, IPancakeV3MasterChef _masterChef, uint128 _liquidity)
    internal
    returns (uint256 _amount0, uint256 _amount1)
  {
    _masterChef.decreaseLiquidity(
      IPancakeV3MasterChef.DecreaseLiquidityParams({
        tokenId: _nftTokenId,
        liquidity: _liquidity,
        amount0Min: 0,
        amount1Min: 0,
        deadline: block.timestamp
      })
    );
    (_amount0, _amount1) = _masterChef.collect(
      IPancakeV3MasterChef.CollectParams({
        tokenId: _nftTokenId,
        recipient: address(this),
        amount0Max: type(uint128).max,
        amount1Max: type(uint128).max
      })
    );
  }

  /// @notice claim trading fee and harvest reward from masterchef.
  /// @dev This is a routine for update worker state from pending rewards.
  function harvest() external {
    _harvest();
  }

  /**
   * @dev Perform the actual claim and harvest.
   * 1. claim trading fee and harvest reward
   * 2. collect performance fee based
   */
  // TODO: handle when either token0 or token1 is reward(cake) token
  function _harvest() internal {
    // Skip harvest if already done before in same block
    if (block.timestamp == lastHarvest) return;
    lastHarvest = uint40(block.timestamp);

    uint256 _nftTokenId = nftTokenId;
    // If tokenId is 0, then nothing to harvest
    if (_nftTokenId == 0) return;

    // SLOADs
    address _performanceFeeBucket = performanceFeeBucket;
    uint16 _performanceFeeBps = performanceFeeBps;
    ERC20 _token0 = token0;
    ERC20 _token1 = token1;
    ERC20 _cake = cake;
    IPancakeV3MasterChef _masterChef = masterChef;

    // _cachedFee is for emitting the event. So we don't have to calc fee * performanceFeeBps / MAX_BPS twice
    uint256 _cachedFee = 0;

    // Handle trading fee
    {
      // Claim all trading fee
      (uint256 _fee0, uint256 _fee1) = _masterChef.collect(
        IPancakeV3MasterChef.CollectParams({
          tokenId: _nftTokenId,
          recipient: address(this),
          amount0Max: type(uint128).max,
          amount1Max: type(uint128).max
        })
      );
      // Collect performance fee on collected trading fee
      if (_fee0 > 0) {
        // Collect token0 performance fee
        _token0.safeTransfer(_performanceFeeBucket, _cachedFee = _fee0 * _performanceFeeBps / MAX_BPS);
        emit LogCollectPerformanceFee(address(_token0), _fee0, _performanceFeeBps, _cachedFee);
      }
      if (_fee1 > 0) {
        // Collect token1 performance fee
        _token1.safeTransfer(_performanceFeeBucket, _cachedFee = _fee1 * _performanceFeeBps / MAX_BPS);
        emit LogCollectPerformanceFee(address(_token1), _fee1, _performanceFeeBps, _cachedFee);
      }
    }

    // Harvest CAKE rewards
    uint256 _cakeRewards = _masterChef.harvest(_nftTokenId, address(this));
    if (_cakeRewards > 0) {
      // Handing CAKE rewards
      // Collect CAKE performance fee
      _cake.safeTransfer(_performanceFeeBucket, _cachedFee = _cakeRewards * _performanceFeeBps / MAX_BPS);
      emit LogCollectPerformanceFee(address(_cake), _cakeRewards, _performanceFeeBps, _cachedFee);
      // Sell CAKE for token0 or token1, if any
      // Find out need to sell CAKE to which side by checking currTick
      (, int24 _currTick,,,,,) = pool.slot0();
      address _tokenOut = address(_token0);
      if (_currTick - posTickLower > posTickUpper - _currTick) {
        // If currTick is closer to tickUpper, then we will sell CAKE for token1
        _tokenOut = address(_token1);
      }

      IPancakeV3Router _router = router;
      uint256 _swapAmount = _cake.balanceOf(address(this));
      _cake.safeApprove(address(_router), _swapAmount);
      // TODO: multi-hop swap
      // Swap CAKE for token0 or token1
      _router.exactInputSingle(
        IPancakeV3Router.ExactInputSingleParams({
          tokenIn: address(_cake),
          tokenOut: _tokenOut,
          fee: poolFee,
          recipient: address(this),
          amountIn: _swapAmount,
          amountOutMinimum: 0,
          sqrtPriceLimitX96: 0
        })
      );
    }
  }

  /// @notice Transfer undeployed token out
  /// @param _token Token to be transfered
  /// @param _amount The amount to transfer
  function transferToExecutor(address _token, uint256 _amount) external nonReentrant onlyExecutorInScope {
    if (_amount == 0) {
      revert PancakeV3Worker_InvalidParams();
    }
    // msg.sender is executor in scope
    ERC20(_token).safeTransfer(msg.sender, _amount);
    emit LogTransferToExecutor(_token, msg.sender, _amount);
  }
}
