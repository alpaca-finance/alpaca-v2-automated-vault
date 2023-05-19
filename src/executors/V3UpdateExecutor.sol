// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// interfaces
import { IExecutor } from "src/interfaces/IExecutor.sol";
import { IWorker } from "src/interfaces/IWorker.sol";
import { IBank } from "src/interfaces/IBank.sol";

// libraries
import { Tasks } from "src/libraries/Constants.sol";

contract V3UpdateExecutor is IExecutor {
  IBank public immutable bank;

  constructor(address _bank) {
    bank = IBank(_bank);
  }

  function execute(bytes calldata _params) external override returns (bytes memory _result) {
    (address _vaultToken, IWorker _worker) = abi.decode(_params, (address, IWorker));
    bank.accrueInterest(_vaultToken);
    _worker.reinvest();
    return abi.encode();
  }
}
