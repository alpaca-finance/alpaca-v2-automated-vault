// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

interface IAutomatedVaultManager {
  struct DepositTokenParams {
    address token;
    uint256 amount;
  }

  // TODO: maybe merge with DepositTokenParams?
  struct WithdrawResult {
    address token;
    uint256 amount;
  }

  function EXECUTOR_IN_SCOPE() external view returns (address);
}
