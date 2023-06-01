// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IERC20 } from "src/interfaces/IERC20.sol";

contract MockVaultOracleAndExecutor {
  uint256 private equityBefore;
  uint256 private debtBefore;
  uint256 private equityAfter;
  uint256 private debtAfter;
  bool private isAfter;

  function setResult(uint256 _equityBefore, uint256 _debtBefore, uint256 _equityAfter, uint256 _debtAfter) external {
    equityBefore = _equityBefore;
    debtBefore = _debtBefore;
    equityAfter = _equityAfter;
    debtAfter = _debtAfter;
  }

  function onUpdate(address, address) external returns (bytes memory) {
    // placeholder
  }

  function onDeposit(address, address) external returns (bytes memory) {
    isAfter = true;
    return "";
  }

  function getEquityAndDebt(address, address) external view returns (uint256, uint256) {
    if (isAfter) return (equityAfter, debtAfter);
    return (equityBefore, debtBefore);
  }
}
