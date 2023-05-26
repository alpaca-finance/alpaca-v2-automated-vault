// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { Multicall } from "@openzeppelin/utils/Multicall.sol";

abstract contract Executor is Multicall {
  function onDeposit(address _worker) external virtual returns (bytes memory _result) { }

  function onUpdate(address _vaultToken, address _worker) external virtual returns (bytes memory _result) { }
}
