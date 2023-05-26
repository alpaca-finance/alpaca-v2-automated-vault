// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

import { IMulticall } from "src/interfaces/IMulticall.sol";

interface IExecutor is IMulticall {
  function onDeposit(address _worker) external returns (bytes memory _result);

  function onUpdate(address _vaultToken, address _worker) external returns (bytes memory _result);
}
