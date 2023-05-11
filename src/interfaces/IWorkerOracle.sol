// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

interface IWorkerOracle {
  function getWorkerEquity(address _worker) external view returns (uint256 _equityUSD);
}
