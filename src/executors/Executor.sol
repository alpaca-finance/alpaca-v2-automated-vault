// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { Multicall } from "@openzeppelin/utils/Multicall.sol";

import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";

// interfaces
import { IAutomatedVaultManager } from "src/interfaces/IAutomatedVaultManager.sol";

abstract contract Executor is Multicall {
  error Executor_NotVaultManager();
  error Executor_NoCurrentWorker();
  error Executor_NoCurrentVaultToken();

  address public immutable vaultManager;
  address private CURRENT_WORKER;
  address private CURRENT_VAULT_TOKEN;

  modifier onlyVaultManager() {
    if (msg.sender != vaultManager) revert Executor_NotVaultManager();
    _;
  }

  constructor(address _vaultManager) {
    vaultManager = _vaultManager;
  }

  function setExecutionScope(address _worker, address _vaultToken) external onlyVaultManager {
    CURRENT_WORKER = _worker;
    CURRENT_VAULT_TOKEN = _vaultToken;
  }

  function _getCurrentWorker() internal view returns (address _currentWorker) {
    _currentWorker = CURRENT_WORKER;
    if (_currentWorker == address(0)) {
      revert Executor_NoCurrentWorker();
    }
  }

  function _getCurrentVaultToken() internal view returns (address _currentVaultToken) {
    _currentVaultToken = CURRENT_VAULT_TOKEN;
    if (_currentVaultToken == address(0)) {
      revert Executor_NoCurrentVaultToken();
    }
  }

  function sweepToWorker() external virtual { }

  function onDeposit(PancakeV3Worker _worker, address _vaultToken) external virtual returns (bytes memory _result) { }

  function onWithdraw(PancakeV3Worker _worker, address _vaultToken, uint256 _sharesToWithdraw)
    external
    virtual
    returns (IAutomatedVaultManager.WithdrawResult[] memory);

  function onUpdate(address _vaultToken, PancakeV3Worker _worker) external virtual returns (bytes memory _result) { }
}
