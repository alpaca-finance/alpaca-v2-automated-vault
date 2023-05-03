// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

interface IExecutor {
  function execute(bytes calldata _params) external returns (bytes memory _result);
}
