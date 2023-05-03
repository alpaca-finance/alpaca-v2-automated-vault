// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

interface IAutomatedVaultManager {
  function EXECUTOR_IN_SCOPE() external view returns (address);
}
