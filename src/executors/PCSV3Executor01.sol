// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";

// contracts
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { Executor } from "src/executors/Executor.sol";

// interfaces
import { IExecutor } from "src/interfaces/IExecutor.sol";
import { IWorker } from "src/interfaces/IWorker.sol";
import { IBank } from "src/interfaces/IBank.sol";
import { IAutomatedVaultManager } from "src/interfaces/IAutomatedVaultManager.sol";

// libraries
import { Tasks } from "src/libraries/Constants.sol";

contract PCSV3Executor01 is Executor {
  using SafeTransferLib for ERC20;

  error PCSV3Executor01_NotSelf();
  error PCSV3Executor01_PositionAlreadyExist();
  error PCSV3Executor01_PositionNotExist();

  IBank public immutable bank;

  modifier onlySelf() {
    if (msg.sender != address(this)) revert PCSV3Executor01_NotSelf();
    _;
  }

  constructor(address _bank) {
    bank = IBank(_bank);
  }

  function onDeposit(PancakeV3Worker _worker, address /* _vaultToken */ )
    external
    override
    returns (bytes memory _result)
  {
    ERC20 _token0 = _worker.token0();
    ERC20 _token1 = _worker.token1();
    uint256 _amountIn0 = _token0.balanceOf(address(this));
    uint256 _amountIn1 = _token1.balanceOf(address(this));

    // bank.borrowOnBehalfOf(_vaultToken, address(_token0), _amountIn0);
    // bank.borrowOnBehalfOf(_vaultToken, address(_token1), _amountIn1);

    // _token0.approve(address(_worker), _amountIn0 * 2);
    // _token1.approve(address(_worker), _amountIn1 * 2);

    // return _worker.doWork(Tasks.INCREASE, abi.encode(_amountIn0 * 2, _amountIn1 * 2));

    if (_amountIn0 != 0) {
      _token0.safeTransfer(address(_worker), _amountIn0);
    }
    if (_amountIn1 != 0) {
      _token1.safeTransfer(address(_worker), _amountIn1);
    }

    return abi.encode(_amountIn0, _amountIn1);
  }

  // NOTE: beware of access control checking
  function onWithdraw(PancakeV3Worker _worker, address _vaultToken, uint256 _sharesToWithdraw)
    external
    override
    returns (IAutomatedVaultManager.WithdrawResult[] memory _results)
  {
    uint128 _liquidity;
    {
      uint256 _tokenId = _worker.nftTokenId();
      if (_tokenId != 0) {
        (,,,,,,, _liquidity,,,,) = _worker.nftPositionManager().positions(_tokenId);
      }
    }
    uint256 _totalShares = ERC20(_vaultToken).totalSupply();

    ERC20 _token0 = _worker.token0();
    ERC20 _token1 = _worker.token1();

    if (_liquidity != 0) {
      _worker.doWork(Tasks.DECREASE, abi.encode(_liquidity * _sharesToWithdraw / _totalShares));
    }

    uint256 _token0Before = _token0.balanceOf(address(this));
    uint256 _token1Before = _token1.balanceOf(address(this));

    uint256 _token0Repay;
    uint256 _token1Repay;
    {
      (, uint256 _token0Debt) = bank.getVaultDebt(_vaultToken, address(_token0));
      _token0Repay = _token0Debt * _sharesToWithdraw / _totalShares;
      (, uint256 _token1Debt) = bank.getVaultDebt(_vaultToken, address(_token1));
      _token1Repay = _token1Debt * _sharesToWithdraw / _totalShares;
    }

    if (_token0Repay != 0) {
      _token0.approve(address(bank), _token0Repay);
      bank.repayOnBehalfOf(_vaultToken, address(_token0), _token0Repay);
    }
    if (_token1Repay != 0) {
      _token1.approve(address(bank), _token1Repay);
      bank.repayOnBehalfOf(_vaultToken, address(_token1), _token1Repay);
    }

    _token0.safeTransfer(msg.sender, _token0Before - _token0Repay);
    _token1.safeTransfer(msg.sender, _token1Before - _token1Repay);

    _results = new IAutomatedVaultManager.WithdrawResult[](2);
    _results[0] =
      IAutomatedVaultManager.WithdrawResult({ token: address(_token0), amount: _token0Before - _token0Repay });
    _results[1] =
      IAutomatedVaultManager.WithdrawResult({ token: address(_token1), amount: _token1Before - _token1Repay });

    return _results;
  }

  function onUpdate(address _vaultToken, PancakeV3Worker _worker) external override returns (bytes memory _result) {
    bank.accrueInterest(_vaultToken);
    _worker.reinvest();
    return abi.encode();
  }

  /// @notice Increase existing position liquidity. Can provide arbitrary amount and worker will zap it in.
  /// Worker will revert if it doesn't have position.
  function increasePosition(PancakeV3Worker _worker, uint256 _amountIn0, uint256 _amountIn1) external onlySelf {
    _worker.token0().safeApprove(address(_worker), _amountIn0);
    _worker.token1().safeApprove(address(_worker), _amountIn1);
    _worker.increasePosition(_amountIn0, _amountIn1);
  }

  /// @notice Open new position for worker (zap add liquidity and deposit nft to masterchef).
  /// Worker will revert if position already exist.
  function openPosition(
    PancakeV3Worker _worker,
    int24 _tickLower,
    int24 _tickUpper,
    uint256 _amountIn0,
    uint256 _amountIn1
  ) external onlySelf {
    _worker.token0().safeApprove(address(_worker), _amountIn0);
    _worker.token1().safeApprove(address(_worker), _amountIn1);
    _worker.openPosition(_tickLower, _tickUpper, _amountIn0, _amountIn1);
  }
}
