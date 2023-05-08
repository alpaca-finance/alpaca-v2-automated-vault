// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

interface IAutomatedVaultManager {
  // to support pool with arbitrary number of tokens
  struct DepositTokenParams {
    address token;
    uint256 amount;
  }

  function EXECUTOR_IN_SCOPE() external view returns (address);
}
