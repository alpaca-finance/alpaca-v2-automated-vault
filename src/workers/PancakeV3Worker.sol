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

  IZapV3 public zapV3;

  // pancake config
  ERC20 public cake;
  ICommonV3PositionManager public nftPositionManager;
  IPancakeV3Router public router;
  IPancakeV3MasterChef public masterChef;

  uint256 public nftTokenId;

  /// Authorization
  mapping(address => bool) public managers;

  event LogIncreaseLiquidity(uint256 _tokenId, uint256 _amount0, uint256 _amount1, uint128 _liquidity);
  event LogSetManager(address indexed manager, bool prevIsManager, bool indexed isManager);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  struct ConstructorParams {
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

    nftPositionManager = _params.positionManager;
    pool = _params.pool;
    router = _params.router;
    masterChef = _params.masterChef;
    poolFee = _params.pool.fee();
    token0 = ERC20(pool.token0());
    token1 = ERC20(address(token1));
    cake = ERC20(masterChef.CAKE());

    zapV3 = _params.zapV3;

    posTickLower = _params.tickLower;
    posTickUpper = _params.tickUpper;

    performanceFeeBps = _params.performanceFeeBps;
  }

  /// @notice Set manager. Only owner can call this function.
  /// @param _manager Manager address
  /// @param _isManager True if manager, false if not
  function setManager(address _manager, bool _isManager) external onlyOwner {
    emit LogSetManager(_manager, managers[_manager], _isManager);
    managers[_manager] = _isManager;
  }

  /// @notice Perform the work. Only manager can call this function.
  /// @dev Main routine. Action depends on task param.
  /// @param _task Task to execute
  /// @param _params Params to execute
  function doWork(
    address,
    /* user */
    Tasks _task,
    bytes calldata _params
  ) external nonReentrant returns (bytes memory) {
    // Check
    if (!managers[msg.sender]) {
      revert PancakeV3Worker_Unauthorized();
    }

    // Effect
    // Before doing anything, reinvest first.
    // _reinvestInternal();

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
      return abi.encode(_increasePositionInternal(_amountIn0, _amountIn1));
    } else if (_task == Tasks.DECREASE) {
      // // Decode params
      // (uint128 _liquidity) = abi.decode(_params, (uint128));
      // // Decrease position.
      // (uint256 _amount0, uint256 _amount1) = _decreasePositionInternal(_liquidity);
      // // Send tokens to caller
      // if (_amount0 > 0) {
      //   token0.safeTransfer(msg.sender, _amount0);
      // }
      // if (_amount1 > 0) {
      //   token1.safeTransfer(msg.sender, _amount1);
      // }
      // return abi.encode(_amount0, _amount1);
    } else if (_task == Tasks.CHANGE_TICK) {
      // (int24 _newTickLower, int24 _newTickUpper) = abi.decode(_params, (int24, int24));
      // _changeTickInternal(_newTickLower, _newTickUpper);
      // return "";
    }
    revert PancakeV3Worker_InvalidTask();
  }

  /// @notice Perform increase position
  /// @dev Tokens must be collected before calling this function
  /// @param _amountIn0 Amount of token0 to increase
  /// @param _amountIn1 Amount of token1 to increase
  function _increasePositionInternal(uint256 _amountIn0, uint256 _amountIn1) internal returns (uint128 _liquidity) {
    (, int24 _currTick,,,,,) = pool.slot0();
    if (posTickLower <= _currTick && _currTick <= posTickUpper) {
      // In range
      _liquidity = _increaseInRange(_amountIn0, _amountIn1);
    } else {
      // Out range
      _liquidity = _increaseOutRange(_currTick, posTickLower, posTickUpper, _amountIn0, _amountIn1);
    }
  }

  /// @notice Perform increase position when ticks are in range.
  /// @param _amountIn0 Amount of token0 to increase
  /// @param _amountIn1 Amount of token1 to increase
  function _increaseInRange(uint256 _amountIn0, uint256 _amountIn1) internal returns (uint128 _liquidity) {
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
    address _tokenIn = _zeroForOne ? address(token0) : address(token1);
    address _tokenOut = _zeroForOne ? address(token1) : address(token0);

    // Swap
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
    _liquidity = _safeMint(address(token0), address(token1), _amountIn0, _amountIn1);
  }

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
  ) internal returns (uint128 _liquidity) {
    // Find out token0 -> token1 or token1 -> token0
    // - If currTick > tickUpper, then we need to swap token0 -> token1
    // - else, then we need to swap token1 -> token0
    bool _zeroForOne = _currTick > _tickUpper;
    address _tokenIn = _zeroForOne ? address(token0) : address(token1);
    address _tokenOut = _zeroForOne ? address(token1) : address(token0);

    // Find out limit price. We will swap until the tick is in range
    // If it is in range and some tokens left, then we will zap.
    int24 _tickSpacing = pool.tickSpacing();
    uint160 _sqrtPriceLimitX96 =
      LibTickMath.getSqrtRatioAtTick(_zeroForOne ? _tickUpper - _tickSpacing - 1 : _tickLower + _tickSpacing + 1);

    // Swap
    uint256 _amountSwap = _zeroForOne ? _amountIn0 : _amountIn1;
    if (_amountSwap > 0) {
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
    _liquidity = _safeMint(address(token0), address(token1), _token0Balance, _token1Balance);
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
    returns (uint128 _liquidity)
  {
    uint256 _amount0 = 0;
    uint256 _amount1 = 0;
    if (nftTokenId == 0) {
      // Position is not existed. Then we need to mint a new position
      // and stake it on PancakeMasterChefV3
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
}
