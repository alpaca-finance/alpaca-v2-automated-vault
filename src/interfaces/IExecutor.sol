// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

import { IMulticall } from "src/interfaces/IMulticall.sol";
import { IAutomatedVaultManager } from "src/interfaces/IAutomatedVaultManager.sol";

interface IExecutor is IMulticall {
  function vaultManager() external view returns (address);

  function setExecutionScope(address _worker, address _vaultToken) external;

  function onDeposit(address _worker, address _vaultToken) external returns (bytes memory _result);

  function onWithdraw(address _worker, address _vaultToken, uint256 _sharesToWithdraw)
    external
    returns (IAutomatedVaultManager.WithdrawResult[] memory);

  function onUpdate(address _vaultToken, address _worker) external returns (bytes memory _result);

  function sweepToWorker() external;
}
