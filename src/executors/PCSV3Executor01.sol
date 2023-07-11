// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";

// contracts
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { Executor } from "src/executors/Executor.sol";
import { PancakeV3VaultOracle } from "src/oracles/PancakeV3VaultOracle.sol";

// interfaces
import { IExecutor } from "src/interfaces/IExecutor.sol";
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { ICommonV3Pool } from "src/interfaces/ICommonV3Pool.sol";
import { IBank } from "src/interfaces/IBank.sol";

// libraries
import { LibTickMath } from "src/libraries/LibTickMath.sol";

contract PCSV3Executor01 is Executor {
  using SafeTransferLib for ERC20;

  error PCSV3Executor01_NotPool();
  error PCSV3Executor01_BadExposure();

  event LogOnDeposit(address _vaultToken, address _worker, uint256 _amountIn0, uint256 _amountIn1);
  event LogOnWithdraw(
    address _worker,
    address _vaultToken,
    uint256 _sharesToWithdraw,
    uint256 _totalShares,
    uint256 _amount0Withdraw,
    uint256 _amount1Withdraw,
    uint256 _amount0AfterRepay,
    uint256 _amount1AfterRepay
  );
  event LogOnUpdate(address _vaultToken, address _worker);
  event LogSweepToWorker(address _token, uint256 _amount);
  event LogIncreasePosition(address _vaultToken, address _worker, uint256 _amountIn0, uint256 _amountIn1);
  event LogOpenPosition(
    address _vaultToken, address _worker, int24 _tickLower, int24 _tickUpper, uint256 _amountIn0, uint256 _amountIn1
  );
  event LogDecreasePosition(address _vaultToken, address _worker, uint128 _liquidity);
  event LogClosePosition(address _vaultToken, address _worker);
  event LogTransferFromWorker(address _vaultToken, address _worker, uint256 _amount);
  event LogBorrow(address _vaultToken, address _token, uint256 _amount);
  event LogRepay(address _vaultToken, address _token, uint256 _amount);
  event LogRepurchase(address _vaultToken, address _borrowToken, uint256 _borrowAmount, uint256 _repayAmount);

  PancakeV3VaultOracle public vaultOracle;

  function initialize(address _vaultManager, address _bank, address _vaultOracle) external initializer {
    // Sanity check
    AutomatedVaultManager(_vaultManager).vaultTokenImplementation();
    PancakeV3VaultOracle(_vaultOracle).maxPriceAge();
    if (_vaultManager != IBank(_bank).vaultManager()) {
      revert Executor_InvalidParams();
    }

    __Ownable2Step_init();

    vaultManager = _vaultManager;
    bank = IBank(_bank);
    vaultOracle = PancakeV3VaultOracle(_vaultOracle);
  }

  function onDeposit(address _worker, address _vaultToken)
    external
    override
    onlyVaultManager
    returns (bytes memory _result)
  {
    ERC20 _token0 = PancakeV3Worker(_worker).token0();
    ERC20 _token1 = PancakeV3Worker(_worker).token1();
    uint256 _amountIn0 = _token0.balanceOf(address(this));
    uint256 _amountIn1 = _token1.balanceOf(address(this));

    if (_amountIn0 != 0) {
      _token0.safeTransfer(_worker, _amountIn0);
    }
    if (_amountIn1 != 0) {
      _token1.safeTransfer(_worker, _amountIn1);
    }

    emit LogOnDeposit(_vaultToken, _worker, _amountIn0, _amountIn1);

    return abi.encode(_amountIn0, _amountIn1);
  }

  /// @notice Decrease liquidity, transfer undeployed funds from worker and repay debt
  function onWithdraw(address _worker, address _vaultToken, uint256 _sharesToWithdraw)
    external
    override
    onlyVaultManager
    onlyOutOfExecutionScope
    returns (AutomatedVaultManager.TokenAmount[] memory _results)
  {
    uint256 _totalShares = ERC20(_vaultToken).totalSupply();
    ERC20 _token0 = PancakeV3Worker(_worker).token0();
    ERC20 _token1 = PancakeV3Worker(_worker).token1();

    // Withdraw from nft liquidity (if applicable) and undeployed funds
    uint256 _amount0Withdraw;
    uint256 _amount1Withdraw;
    {
      _amount0Withdraw = _token0.balanceOf(_worker) * _sharesToWithdraw / _totalShares;
      _amount1Withdraw = _token1.balanceOf(_worker) * _sharesToWithdraw / _totalShares;
      {
        uint256 _tokenId = PancakeV3Worker(_worker).nftTokenId();
        if (_tokenId != 0) {
          (,,,,,,, uint128 _liquidity,,,,) = PancakeV3Worker(_worker).nftPositionManager().positions(_tokenId);
          if (_liquidity != 0) {
            (uint256 _amount0Decreased, uint256 _amount1Decreased) =
              PancakeV3Worker(_worker).decreasePosition(uint128(_liquidity * _sharesToWithdraw / _totalShares));
            // Tokens still with worker after `decreasePosition` so we need to add to withdrawal
            _amount0Withdraw += _amount0Decreased;
            _amount1Withdraw += _amount1Decreased;
          }
        }
      }
      // Withdraw undeployed funds and decreased liquidity if any
      if (_amount0Withdraw != 0) {
        PancakeV3Worker(_worker).transferToExecutor(address(_token0), _amount0Withdraw);
      }
      if (_amount1Withdraw != 0) {
        PancakeV3Worker(_worker).transferToExecutor(address(_token1), _amount1Withdraw);
      }
    }

    // Repay with amount withdrawn, swap other token to repay token if not enough
    // NOTE: can't repay if vault has no equity (position value + undeployed funds < debt value)
    // due to amount withdrawn is not enough to repay and will revert
    _repayOnWithdraw(_worker, _vaultToken, _sharesToWithdraw, _totalShares, _amount0Withdraw, _token0, _token1);
    _repayOnWithdraw(_worker, _vaultToken, _sharesToWithdraw, _totalShares, _amount1Withdraw, _token1, _token0);

    // What is left after repayment belongs to user
    uint256 _amount0AfterRepay = _token0.balanceOf(address(this));
    if (_amount0AfterRepay != 0) {
      _token0.safeTransfer(msg.sender, _amount0AfterRepay);
    }
    uint256 _amount1AfterRepay = _token1.balanceOf(address(this));
    if (_amount1AfterRepay != 0) {
      _token1.safeTransfer(msg.sender, _amount1AfterRepay);
    }

    emit LogOnWithdraw(
      _worker,
      _vaultToken,
      _sharesToWithdraw,
      _totalShares,
      _amount0Withdraw,
      _amount1Withdraw,
      _amount0AfterRepay,
      _amount1AfterRepay
    );

    _results = new AutomatedVaultManager.TokenAmount[](2);
    _results[0] = AutomatedVaultManager.TokenAmount({ token: address(_token0), amount: _amount0AfterRepay });
    _results[1] = AutomatedVaultManager.TokenAmount({ token: address(_token1), amount: _amount1AfterRepay });
    return _results;
  }

  function _repayOnWithdraw(
    address _worker,
    address _vaultToken,
    uint256 _sharesToWithdraw,
    uint256 _totalShares,
    uint256 _repayTokenBalance,
    ERC20 _repayToken,
    ERC20 _otherToken
  ) internal {
    uint256 _repayAmount;
    (, uint256 _debtAmount) = bank.getVaultDebt(_vaultToken, address(_repayToken));
    _repayAmount = _debtAmount * _sharesToWithdraw / _totalShares;
    // Early return if no repay
    if (_repayAmount == 0) return;

    // Swap if not enough to repay
    if (_repayAmount > _repayTokenBalance) {
      uint256 _diffAmount = _repayAmount - _repayTokenBalance;
      bool _zeroForOne = address(_otherToken) < address(_repayToken);

      ICommonV3Pool _pool = PancakeV3Worker(_worker).pool();
      _pool.swap(
        address(this),
        _zeroForOne,
        -int256(_diffAmount), // negative = exact output
        _zeroForOne ? LibTickMath.MIN_SQRT_RATIO + 1 : LibTickMath.MAX_SQRT_RATIO - 1, // no price limit
        abi.encode(_pool.token0(), _pool.token1(), _pool.fee())
      );
    }

    _repayToken.safeApprove(address(bank), _repayAmount);
    bank.repayOnBehalfOf(_vaultToken, address(_repayToken), _repayAmount);
    emit LogRepay(_vaultToken, address(_repayToken), _repayAmount);
  }

  function onUpdate(address _worker, address _vaultToken)
    external
    override
    onlyVaultManager
    returns (bytes memory _result)
  {
    bank.accrueInterest(_vaultToken);
    PancakeV3Worker(_worker).harvest();
    emit LogOnUpdate(_vaultToken, _worker);
  }

  function sweepToWorker() external override onlyVaultManager {
    address _worker = _getCurrentWorker();
    ICommonV3Pool _pool = PancakeV3Worker(_worker).pool();
    _sweepTo(ERC20(_pool.token0()), _worker);
    _sweepTo(ERC20(_pool.token1()), _worker);
  }

  function _sweepTo(ERC20 _token, address _to) internal {
    uint256 _balance = _token.balanceOf(address(this));
    if (_balance != 0) {
      _token.safeTransfer(_to, _balance);
      emit LogSweepToWorker(address(_token), _balance);
    }
  }

  /// @notice Increase existing position liquidity using worker's undeployed funds.
  /// Worker will revert if it doesn't have position.
  function increasePosition(uint256 _amountIn0, uint256 _amountIn1) external onlyVaultManager {
    address _worker = _getCurrentWorker();
    PancakeV3Worker(_worker).increasePosition(_amountIn0, _amountIn1);
    emit LogIncreasePosition(_getCurrentVaultToken(), _worker, _amountIn0, _amountIn1);
  }

  /// @notice Open new position (zap, add liquidity and deposit nft to masterchef) for worker
  /// using worker's undeployed funds. Worker will revert if position already exist.
  /// Can't open position for pool that doesn't have CAKE reward in masterChef.
  function openPosition(int24 _tickLower, int24 _tickUpper, uint256 _amountIn0, uint256 _amountIn1)
    external
    onlyVaultManager
  {
    address _worker = _getCurrentWorker();
    PancakeV3Worker(_worker).openPosition(_tickLower, _tickUpper, _amountIn0, _amountIn1);
    emit LogOpenPosition(_getCurrentVaultToken(), _worker, _tickLower, _tickUpper, _amountIn0, _amountIn1);
  }

  function decreasePosition(uint128 _liquidity) external onlyVaultManager {
    address _worker = _getCurrentWorker();
    PancakeV3Worker(_worker).decreasePosition(_liquidity);
    emit LogDecreasePosition(_getCurrentVaultToken(), _worker, _liquidity);
  }

  function closePosition() external onlyVaultManager {
    address _worker = _getCurrentWorker();
    PancakeV3Worker(_worker).closePosition();
    emit LogClosePosition(_getCurrentVaultToken(), _worker);
  }

  function transferFromWorker(address _token, uint256 _amount) external onlyVaultManager {
    address _worker = _getCurrentWorker();
    PancakeV3Worker(_worker).transferToExecutor(_token, _amount);
    emit LogTransferFromWorker(_getCurrentVaultToken(), _worker, _amount);
  }

  /// @notice Borrow token from Bank. Borrowed funds will be sent directly to worker.
  function borrow(address _token, uint256 _amount) external onlyVaultManager {
    address _vaultToken = _getCurrentVaultToken();
    bank.borrowOnBehalfOf(_vaultToken, _token, _amount);
    ERC20(_token).safeTransfer(_getCurrentWorker(), _amount);
    emit LogBorrow(_vaultToken, _token, _amount);
  }

  /// @notice Repay token back to Bank
  function repay(address _token, uint256 _amount) external onlyVaultManager {
    address _vaultToken = _getCurrentVaultToken();
    ERC20(_token).safeApprove(address(bank), _amount);
    bank.repayOnBehalfOf(_vaultToken, _token, _amount);
    emit LogRepay(_vaultToken, _token, _amount);
  }

  /// @notice Adjust vault exposure by borrowing a token, swap to another and repay.
  // TODO: include token here to exposure
  function repurchase(address _borrowToken, uint256 _borrowAmount) external onlyVaultManager {
    // Check
    address _vaultToken = _getCurrentVaultToken();
    address _worker = _getCurrentWorker();
    ERC20 _token0 = PancakeV3Worker(_worker).token0();
    ERC20 _token1 = PancakeV3Worker(_worker).token1();
    bool _zeroForOne;
    address _repayToken;
    bool _increaseExposure;
    if (_borrowToken == address(_token0)) {
      _zeroForOne = true;
      _repayToken = address(_token1);
      _increaseExposure = PancakeV3Worker(_worker).isToken0Base();
    } else if (_borrowToken == address(_token1)) {
      _zeroForOne = false;
      _repayToken = address(_token0);
      _increaseExposure = !PancakeV3Worker(_worker).isToken0Base();
    } else {
      revert Executor_InvalidParams();
    }
    int256 _exposureBefore = vaultOracle.getExposure(_vaultToken, _worker);
    // No repurchase if exposure already 0
    if (_exposureBefore == 0) {
      revert PCSV3Executor01_BadExposure();
    }

    // Borrow
    bank.borrowOnBehalfOf(_vaultToken, _borrowToken, _borrowAmount);

    // Swap
    ICommonV3Pool _pool = PancakeV3Worker(_worker).pool();
    (int256 _amount0, int256 _amount1) = _pool.swap(
      address(this),
      _zeroForOne,
      int256(_borrowAmount), // positive = exact input
      _zeroForOne ? LibTickMath.MIN_SQRT_RATIO + 1 : LibTickMath.MAX_SQRT_RATIO - 1, // no price limit
      abi.encode(address(_token0), address(_token1), _pool.fee())
    );
    uint256 _swapAmountOut = uint256(_zeroForOne ? -_amount1 : -_amount0);

    // Check vault delta exposure
    {
      // If borrow token is base, then delta exposure is swapAmountOut (repay volatile token with swapAmountOut, increasing exposure)
      // If borrow token is not base, then delta exposure is -borrowAmount (borrow volatile token, reducing exposure)
      int256 _deltaExposure = _increaseExposure ? int256(_swapAmountOut) : -int256(_borrowAmount);

      // Revert if resulting exposure deviate further from 0 or causing exposure to flip sign
      // Current exposure is long, can't make it longer or flip to short
      if (_exposureBefore > 0 && (_deltaExposure > 0 || _exposureBefore + _deltaExposure < 0)) {
        revert PCSV3Executor01_BadExposure();
      }
      // Current exposure is short, can't make it shorter or flip to long
      if (_exposureBefore < 0 && (_deltaExposure < 0 || _exposureBefore + _deltaExposure > 0)) {
        revert PCSV3Executor01_BadExposure();
      }
    }

    // Repay
    ERC20(_repayToken).safeApprove(address(bank), _swapAmountOut);
    bank.repayOnBehalfOf(_vaultToken, _repayToken, _swapAmountOut);

    emit LogRepurchase(_vaultToken, _borrowToken, _borrowAmount, _swapAmountOut);
  }

  function pancakeV3SwapCallback(int256 _amount0Delta, int256 _amount1Delta, bytes calldata _data) external {
    (address _token0, address _token1, uint24 _fee) = abi.decode(_data, (address, address, uint24));
    address _pool = address(
      uint160(
        uint256(
          keccak256(
            abi.encodePacked(
              hex"ff",
              0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9,
              keccak256(abi.encode(_token0, _token1, _fee)),
              bytes32(0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2)
            )
          )
        )
      )
    );
    if (msg.sender == _pool) {
      if (_amount0Delta > 0) {
        ERC20(_token0).safeTransfer(msg.sender, uint256(_amount0Delta));
      } else {
        ERC20(_token1).safeTransfer(msg.sender, uint256(_amount1Delta));
      }
    } else {
      revert PCSV3Executor01_NotPool();
    }
  }
}
