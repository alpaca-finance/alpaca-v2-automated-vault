// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { Multicall } from "@openzeppelin/utils/Multicall.sol";

import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";

abstract contract Executor is Multicall {
  function onDeposit(PancakeV3Worker _worker, address _vaultToken) external virtual returns (bytes memory _result) { }

  function onWithdraw(PancakeV3Worker _worker, address _vaultToken, uint256 _sharesToWithdraw, address _recipient)
    external
    virtual
    returns (bytes memory _result);

  function onUpdate(address _vaultToken, PancakeV3Worker _worker) external virtual returns (bytes memory _result) { }
}
