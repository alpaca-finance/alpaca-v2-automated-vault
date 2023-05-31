// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// interfaces
import { IWorker } from "src/interfaces/IWorker.sol";
import { IAutomatedVaultManager } from "src/interfaces/IAutomatedVaultManager.sol";
import { IZapV3 } from "src/interfaces/IZapV3.sol";
import { ICommonV3Pool } from "src/interfaces/ICommonV3Pool.sol";
import { ICommonV3PositionManager } from "src/interfaces/ICommonV3PositionManager.sol";
import { IPancakeV3Router } from "src/interfaces/pancake-v3/IPancakeV3Router.sol";
import { IPancakeV3MasterChef } from "src/interfaces/pancake-v3/IPancakeV3MasterChef.sol";

// libraries
import { LibTickMath } from "src/libraries/LibTickMath.sol";
import { Tasks, MAX_BPS } from "src/libraries/Constants.sol";

contract PancakeV3Worker is IWorker, Initializable, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable {
  using SafeTransferLib for ERC20;

  error PancakeV3Worker_Unauthorized();
  error PancakeV3Worker_InvalidTask();
  error PancakeV3Worker_PositionExist();
  error PancakeV3Worker_PositionNotExist();

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
  uint40 public lastReinvest;

  IZapV3 public zapV3;

  // pancake config
  ERC20 public cake;
  ICommonV3PositionManager public nftPositionManager;
  IPancakeV3Router public router;
  IPancakeV3MasterChef public masterChef;

  uint256 public nftTokenId;

  /// Authorization
  IAutomatedVaultManager public vaultManager;

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

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  struct ConstructorParams {
    IAutomatedVaultManager vaultManager;
    ICommonV3PositionManager positionManager;
    ICommonV3Pool pool;
    IPancakeV3Router router;
    IPancakeV3MasterChef masterChef;
    IZapV3 zapV3;
    address performanceFeeBucket;
    int24 tickLower;
    int24 tickUpper;
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

    posTickLower = _params.tickLower;
    posTickUpper = _params.tickUpper;

    performanceFeeBps = _params.performanceFeeBps;
    performanceFeeBucket = _params.performanceFeeBucket;
  }

  // TODO: deprecate doWork in favor of individual function
  /// @notice Perform the work. Only manager can call this function.
  /// @dev Main routine. Action depends on task param.
  /// @param _task Task to execute
  /// @param _params Params to execute
  function doWork(Tasks _task, bytes calldata _params) external nonReentrant returns (bytes memory) {
    // Check
    if (msg.sender != vaultManager.EXECUTOR_IN_SCOPE()) {
      revert PancakeV3Worker_Unauthorized();
    }

    // Effect
    // Before doing anything, harvest first.
    _harvest();

    // Perform action according to the command
    if (_task == Tasks.INCREASE) {
      // Decode params
      (uint256 _amountIn0, uint256 _amountIn1) = abi.decode(_params, (uint256, uint256));
      // Collect tokens from caller
      if (_amountIn0 > 0) {
        token0.safeTransferFrom(msg.sender, address(this), _amountIn0);
      }
      if (_amountIn1 > 0) {
        token1.safeTransferFrom(msg.sender, address(this), _amountIn1);
      }
      // Increase position.
      (uint128 _liquidity, uint256 _amount0, uint256 _amount1) = _increasePositionInternal(_amountIn0, _amountIn1);
      return abi.encode(_liquidity, _amount0, _amount1);
    } else if (_task == Tasks.DECREASE) {
      // Decode params
      (uint128 _liquidity) = abi.decode(_params, (uint128));
      // Decrease position.
      (uint256 _amount0, uint256 _amount1) = _decreasePositionInternal(_liquidity);
      // Send tokens to caller
      if (_amount0 > 0) {
        token0.safeTransfer(msg.sender, _amount0);
      }
      if (_amount1 > 0) {
        token1.safeTransfer(msg.sender, _amount1);
      }
      return abi.encode(_amount0, _amount1);
    } else if (_task == Tasks.CHANGE_TICK) {
      // (int24 _newTickLower, int24 _newTickUpper) = abi.decode(_params, (int24, int24));
      // _changeTickInternal(_newTickLower, _newTickUpper);
      // return "";
    }
    revert PancakeV3Worker_InvalidTask();
  }

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

    // Pull tokens
    if (_amountIn0 != 0) {
      _token0.safeTransferFrom(msg.sender, address(this), _amountIn0);
    }
    if (_amountIn1 != 0) {
      _token1.safeTransferFrom(msg.sender, address(this), _amountIn1);
    }

    // Prepare optimal tokens for adding liquidity
    (uint256 _amount0Desired, uint256 _amount1Desired) = _prepareOptimalTokensForIncrease(
      address(_token0), address(_token1), _tickLower, _tickUpper, _amountIn0, _amountIn1
    );

    // Mint new position and stake it with masterchef
    // SLOAD
    ICommonV3PositionManager _nftPositionManager = nftPositionManager;

    ERC20(_token0).safeApprove(address(_nftPositionManager), _amount0Desired);
    ERC20(_token1).safeApprove(address(_nftPositionManager), _amount1Desired);
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

    // Pull tokens
    if (_amountIn0 != 0) {
      _token0.safeTransferFrom(msg.sender, address(this), _amountIn0);
    }
    if (_amountIn1 != 0) {
      _token1.safeTransferFrom(msg.sender, address(this), _amountIn1);
    }

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

  // TODO: deprecate this
  /// @notice Perform increase position
  /// @dev Tokens must be collected before calling this function
  /// @param _amountIn0 Amount of token0 to increase
  /// @param _amountIn1 Amount of token1 to increase
  function _increasePositionInternal(uint256 _amountIn0, uint256 _amountIn1)
    internal
    returns (uint128 _liquidity, uint256 _amount0, uint256 _amount1)
  {
    (, int24 _currTick,,,,,) = pool.slot0();
    if (posTickLower <= _currTick && _currTick <= posTickUpper) {
      // In range
      return _increaseInRange(_amountIn0, _amountIn1);
    } else {
      // Out range
      return _increaseOutRange(_currTick, posTickLower, posTickUpper, _amountIn0, _amountIn1);
    }
  }

  // TODO: deprecate this
  /// @notice Perform increase position when ticks are in range.
  /// @param _amountIn0 Amount of token0 to increase
  /// @param _amountIn1 Amount of token1 to increase
  function _increaseInRange(uint256 _amountIn0, uint256 _amountIn1)
    internal
    returns (uint128 _liquidity, uint256 _amount0, uint256 _amount1)
  {
    // Calculate zap in amount and direction.
    (uint256 _amountSwap, uint256 _minAmountOut, bool _zeroForOne) = zapV3.calc(
      IZapV3.CalcParams({
        pool: address(pool),
        amountIn0: _amountIn0,
        amountIn1: _amountIn1,
        tickLower: posTickLower,
        tickUpper: posTickUpper
      })
    );

    // Find out tokenIn and tokenOut
    address _tokenIn;
    address _tokenOut;
    if (_zeroForOne) {
      _tokenIn = address(token0);
      _tokenOut = address(token1);
    } else {
      _tokenIn = address(token1);
      _tokenOut = address(token0);
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

    // Update amountIn0 and amountIn1
    _amountIn0 = token0.balanceOf(address(this));
    _amountIn1 = token1.balanceOf(address(this));

    // Mint the position and stake or increase liquidity of staked position.
    (_liquidity, _amount0, _amount1) = _safeMint(address(token0), address(token1), _amountIn0, _amountIn1);
  }

  // TODO: deprecate this
  /// @notice Perform increase position when ticks are out of range.
  /// @param _currTick Current tick
  /// @param _tickLower Tick lower
  /// @param _tickUpper Tick upper
  /// @param _amountIn0 Amount of token0 to increase
  /// @param _amountIn1 Amount of token1 to increase
  function _increaseOutRange(
    int24 _currTick,
    int24 _tickLower,
    int24 _tickUpper,
    uint256 _amountIn0,
    uint256 _amountIn1
  ) internal returns (uint128 _liquidity, uint256 _amount0, uint256 _amount1) {
    // Find out token0 -> token1 or token1 -> token0
    // - If currTick > tickUpper, then we need to swap token0 -> token1
    // - else, then we need to swap token1 -> token0
    bool _zeroForOne = _currTick > _tickUpper;
    address _tokenIn;
    address _tokenOut;
    if (_zeroForOne) {
      _tokenIn = address(token0);
      _tokenOut = address(token1);
    } else {
      _tokenIn = address(token1);
      _tokenOut = address(token0);
    }

    // Find out limit price. We will swap until the tick is in range
    // If it is in range and some tokens left, then we will zap.
    // TODO: optimize
    int24 _tickSpacing = pool.tickSpacing();
    {
      uint160 _sqrtPriceLimitX96 =
        LibTickMath.getSqrtRatioAtTick(_zeroForOne ? _tickUpper - _tickSpacing - 1 : _tickLower + _tickSpacing + 1);
      // Swap
      uint256 _amountSwap = _zeroForOne ? _amountIn0 : _amountIn1;
      if (_amountSwap > 0) {
        ERC20(_tokenIn).safeApprove(address(router), _amountSwap);
        router.exactInputSingle(
          IPancakeV3Router.ExactInputSingleParams({
            tokenIn: _tokenIn,
            tokenOut: _tokenOut,
            fee: poolFee,
            recipient: address(this),
            amountIn: _zeroForOne ? _amountIn0 : _amountIn1,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: _sqrtPriceLimitX96
          })
        );
      }
    }

    // Cached balance of token0 and token1 here
    uint256 _token0Balance = token0.balanceOf(address(this));
    uint256 _token1Balance = token1.balanceOf(address(this));

    // If currTick after swap is in range, then increase in range.
    (, _currTick,,,,,) = pool.slot0();
    if (_tickLower <= _currTick && _currTick <= _tickUpper) {
      return _increaseInRange(_token0Balance, _token1Balance);
    }

    // If currTick after swap is still out of range, meaning all tokens are swapped.
    // Hence, we can add liquidity on single side.
    (_liquidity, _amount0, _amount1) = _safeMint(address(token0), address(token1), _token0Balance, _token1Balance);
  }

  /// @notice Perform safe enter V3 position.
  /// @dev If position is not existed, then mint a new position and stake.
  /// Else increase liquidity through MasterChefV3.
  /// @param _token0 Address of token0
  /// @param _token1 Address of token1
  /// @param _amountIn0 Amount of token0 to enter
  /// @param _amountIn1 Amount of token1 to enter
  function _safeMint(address _token0, address _token1, uint256 _amountIn0, uint256 _amountIn1)
    internal
    returns (uint128 _liquidity, uint256 _amount0, uint256 _amount1)
  {
    if (nftTokenId == 0) {
      // Position is not existed. Then we need to mint a new position
      // and stake it on PancakeMasterChefV3
      ERC20(_token0).safeApprove(address(nftPositionManager), _amountIn0);
      ERC20(_token1).safeApprove(address(nftPositionManager), _amountIn1);
      (nftTokenId, _liquidity, _amount0, _amount1) = nftPositionManager.mint(
        ICommonV3PositionManager.MintParams({
          token0: _token0,
          token1: _token1,
          fee: poolFee,
          tickLower: posTickLower,
          tickUpper: posTickUpper,
          amount0Desired: _amountIn0,
          amount1Desired: _amountIn1,
          amount0Min: 0,
          amount1Min: 0,
          recipient: address(this),
          deadline: block.timestamp
        })
      );

      // Stake to PancakeMasterChefV3
      nftPositionManager.safeTransferFrom(address(this), address(masterChef), nftTokenId);
    } else {
      // If already has a position, then we need to increase a position on through MasterChefV3
      ERC20(_token0).safeApprove(address(masterChef), _amountIn0);
      ERC20(_token1).safeApprove(address(masterChef), _amountIn1);
      (_liquidity, _amount0, _amount1) = masterChef.increaseLiquidity(
        IPancakeV3MasterChef.IncreaseLiquidityParams({
          tokenId: nftTokenId,
          amount0Desired: _amountIn0,
          amount1Desired: _amountIn1,
          amount0Min: 0,
          amount1Min: 0,
          deadline: block.timestamp
        })
      );
    }

    emit LogIncreaseLiquidity(nftTokenId, _amount0, _amount1, _liquidity);
  }

  /// @notice Perform decrease position according to a given liquidity.
  /// @param _liquidity Liquidity to decrease
  function _decreasePositionInternal(uint128 _liquidity) internal returns (uint256 _amount0, uint256 _amount1) {
    masterChef.decreaseLiquidity(
      IPancakeV3MasterChef.DecreaseLiquidityParams({
        tokenId: nftTokenId,
        liquidity: _liquidity,
        amount0Min: 0,
        amount1Min: 0,
        deadline: block.timestamp
      })
    );
    (_amount0, _amount1) = masterChef.collect(
      IPancakeV3MasterChef.CollectParams({
        tokenId: nftTokenId,
        recipient: address(this),
        amount0Max: type(uint128).max,
        amount1Max: type(uint128).max
      })
    );
    emit LogDecreaseLiquidity(nftTokenId, _amount0, _amount1, _liquidity);
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
    // Skip reinvest if already done before in same block
    if (block.timestamp == lastReinvest) return;
    lastReinvest = uint40(block.timestamp);

    // If tokenId is 0, then nothing to reinvest
    if (nftTokenId == 0) return;

    // Claim all trading fee
    (uint256 _fee0, uint256 _fee1) = masterChef.collect(
      IPancakeV3MasterChef.CollectParams({
        tokenId: nftTokenId,
        recipient: address(this),
        amount0Max: type(uint128).max,
        amount1Max: type(uint128).max
      })
    );

    // Harvest CAKE rewards
    uint256 _cakeRewards = masterChef.harvest(nftTokenId, address(this));
    // Collect performance fee
    // SLOAD performanceFeeBucket and performanceFeeBps to save gas
    address _performanceFeeBucket = performanceFeeBucket;
    uint16 _performanceFeeBps = performanceFeeBps;
    // _cachedFee is for emitting the event. So we don't have to calc fee * performanceFeeBps / MAX_BPS twice
    uint256 _cachedFee = 0;
    // Handling performance fees

    if (_fee0 > 0) {
      // Collect token0 performance fee
      token0.safeTransfer(_performanceFeeBucket, _cachedFee = _fee0 * _performanceFeeBps / MAX_BPS);
      emit LogCollectPerformanceFee(address(token0), _fee0, _performanceFeeBps, _cachedFee);
    }
    if (_fee1 > 0) {
      // Collect token1 performance fee
      token1.safeTransfer(_performanceFeeBucket, _cachedFee = _fee1 * _performanceFeeBps / MAX_BPS);
      emit LogCollectPerformanceFee(address(token1), _fee1, _performanceFeeBps, _cachedFee);
    }
    if (_cakeRewards > 0) {
      // Handing CAKE rewards
      // Collect CAKE performance fee
      cake.safeTransfer(_performanceFeeBucket, _cachedFee = _cakeRewards * _performanceFeeBps / MAX_BPS);
      emit LogCollectPerformanceFee(address(cake), _cakeRewards, _performanceFeeBps, _cachedFee);
      // Sell CAKE for token0 or token1, if any
      // Find out need to sell CAKE to which side by checking currTick
      (, int24 _currTick,,,,,) = pool.slot0();
      address _tokenOut = address(token0);
      if (_currTick - posTickLower > posTickUpper - _currTick) {
        // If currTick is closer to tickUpper, then we will sell CAKE for token1
        _tokenOut = address(token1);
      }

      uint256 _swapAmount = cake.balanceOf(address(this));
      cake.safeApprove(address(router), _swapAmount);
      // TODO: multi-hop swap
      // Swap CAKE for token0 or token1
      router.exactInputSingle(
        IPancakeV3Router.ExactInputSingleParams({
          tokenIn: address(cake),
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
}
