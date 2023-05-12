// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

interface IVaultOracle {
  function getEquity(address _worker) external view returns (uint256 _equityUSD);
}
