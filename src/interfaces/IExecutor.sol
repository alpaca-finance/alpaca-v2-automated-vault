// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

import { IWorker } from "src/interfaces/IWorker.sol";

interface IExecutor {
  function onDeposit(IWorker _worker) external returns (bytes memory _result);

  function onUpdate(address _vaultToken, IWorker _worker) external returns (bytes memory _result);
}
