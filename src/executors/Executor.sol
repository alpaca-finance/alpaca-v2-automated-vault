// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { Multicall } from "@openzeppelin/utils/Multicall.sol";

// interfaces
import { IWorker } from "src/interfaces/IWorker.sol";

abstract contract Executor is Multicall {
  function onDeposit(IWorker _worker) external virtual returns (bytes memory _result) { }

  function onUpdate(address _vaultToken, IWorker _worker) external virtual returns (bytes memory _result) { }
}
