// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";

// contracts
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";

// interfaces
import { IExecutor } from "src/interfaces/IExecutor.sol";
import { IWorker } from "src/interfaces/IWorker.sol";
import { IBank } from "src/interfaces/IBank.sol";

// libraries
import { Tasks } from "src/libraries/Constants.sol";

contract SimpleV3DepositExecutor is IExecutor {
  PancakeV3Worker public immutable pancakeV3Worker;
  IBank public immutable bank;

  constructor(address _worker, address _bank) {
    pancakeV3Worker = PancakeV3Worker(_worker);
    bank = IBank(_bank);
  }

  function execute(bytes calldata /* _params */ ) external override returns (bytes memory _result) {
    ERC20 _token0 = pancakeV3Worker.token0();
    ERC20 _token1 = pancakeV3Worker.token1();
    uint256 _amountIn0 = _token0.balanceOf(address(this));
    uint256 _amountIn1 = _token1.balanceOf(address(this));

    bank.borrowOnBehalfOf(msg.sender, address(_token0), _amountIn0);
    bank.borrowOnBehalfOf(msg.sender, address(_token1), _amountIn1);

    _token0.approve(address(pancakeV3Worker), _amountIn0 * 2);
    _token1.approve(address(pancakeV3Worker), _amountIn1 * 2);

    return pancakeV3Worker.doWork(address(0), Tasks.INCREASE, abi.encode(_amountIn0 * 2, _amountIn1 * 2));
  }
}
