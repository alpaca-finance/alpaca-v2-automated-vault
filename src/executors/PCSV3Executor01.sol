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

// libraries
import { Tasks } from "src/libraries/Constants.sol";

contract PCSV3Executor01 is Executor {
  IBank public immutable bank;

  constructor(address _bank) {
    bank = IBank(_bank);
  }

  function onDeposit(IWorker _worker) external override returns (bytes memory _result) {
    PancakeV3Worker _pcsWorker = PancakeV3Worker(address(_worker));

    ERC20 _token0 = _pcsWorker.token0();
    ERC20 _token1 = _pcsWorker.token1();
    uint256 _amountIn0 = _token0.balanceOf(address(this));
    uint256 _amountIn1 = _token1.balanceOf(address(this));

    bank.borrowOnBehalfOf(msg.sender, address(_token0), _amountIn0);
    bank.borrowOnBehalfOf(msg.sender, address(_token1), _amountIn1);

    _token0.approve(address(_pcsWorker), _amountIn0 * 2);
    _token1.approve(address(_pcsWorker), _amountIn1 * 2);

    return _worker.doWork(Tasks.INCREASE, abi.encode(_amountIn0 * 2, _amountIn1 * 2));
  }

  function onUpdate(address _vaultToken, IWorker _worker) external override returns (bytes memory _result) {
    bank.accrueInterest(_vaultToken);
    _worker.reinvest();
    return abi.encode();
  }

  function execute(bytes calldata _params) external override returns (bytes memory _result) { }
}
