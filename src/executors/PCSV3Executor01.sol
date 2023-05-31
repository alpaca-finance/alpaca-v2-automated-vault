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
import { ICommonV3Pool } from "src/interfaces/ICommonV3Pool.sol";

// libraries
import { Tasks } from "src/libraries/Constants.sol";
import { LibTickMath } from "src/libraries/LibTickMath.sol";

contract PCSV3Executor01 is Executor {
  using SafeTransferLib for ERC20;

  error PCSV3Executor01_NotSelf();
  error PCSV3Executor01_PositionAlreadyExist();
  error PCSV3Executor01_PositionNotExist();
  error PCSV3Executor01_NotPool();

  IBank public immutable bank;

  // TODO: change to onlyVaultManager since delegatecall doesn't change msg.sender
  modifier onlySelf() {
    if (msg.sender != address(this)) revert PCSV3Executor01_NotSelf();
    _;
  }

  constructor(address _vaultManager, address _bank) Executor(_vaultManager) {
    bank = IBank(_bank);
  }

  function onDeposit(PancakeV3Worker _worker, address /* _vaultToken */ )
    external
    override
    onlyVaultManager
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
    onlyVaultManager
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

  function onUpdate(address _vaultToken, PancakeV3Worker _worker)
    external
    override
    onlyVaultManager
    returns (bytes memory _result)
  {
    bank.accrueInterest(_vaultToken);
    _worker.reinvest();
    return abi.encode();
  }

  /// @notice Increase existing position liquidity. Can provide arbitrary amount and worker will zap it in.
  /// Worker will revert if it doesn't have position.
  function increasePosition(uint256 _amountIn0, uint256 _amountIn1) external onlySelf {
    PancakeV3Worker _worker = PancakeV3Worker(_getCurrentWorker());
    _worker.token0().safeApprove(address(_worker), _amountIn0);
    _worker.token1().safeApprove(address(_worker), _amountIn1);
    _worker.increasePosition(_amountIn0, _amountIn1);
  }

  /// @notice Open new position for worker (zap add liquidity and deposit nft to masterchef).
  /// Worker will revert if position already exist.
  function openPosition(int24 _tickLower, int24 _tickUpper, uint256 _amountIn0, uint256 _amountIn1) external onlySelf {
    PancakeV3Worker _worker = PancakeV3Worker(_getCurrentWorker());
    _worker.token0().safeApprove(address(_worker), _amountIn0);
    _worker.token1().safeApprove(address(_worker), _amountIn1);
    _worker.openPosition(_tickLower, _tickUpper, _amountIn0, _amountIn1);
  }

  function decreasePosition(uint128 _liquidity) external onlySelf {
    PancakeV3Worker(_getCurrentWorker()).decreasePosition(_liquidity);
  }

  function closePosition() external onlySelf {
    PancakeV3Worker(_getCurrentWorker()).closePosition();
  }

  function withdrawUndeployedFunds(address _token, uint256 _amount) external onlySelf {
    PancakeV3Worker(_getCurrentWorker()).withdrawUndeployedFunds(_token, _amount);
  }

  function pancakeV3SwapExactInputSingle(bool _zeroForOne, uint256 _amountIn) external onlySelf {
    ICommonV3Pool _pool = PancakeV3Worker(_getCurrentWorker()).pool();
    _pool.swap(
      address(this),
      _zeroForOne,
      int256(_amountIn), // positive = exact input
      _zeroForOne ? LibTickMath.MIN_SQRT_RATIO + 1 : LibTickMath.MAX_SQRT_RATIO - 1,
      abi.encode(_pool.token0(), _pool.token1(), _pool.fee())
    );
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
