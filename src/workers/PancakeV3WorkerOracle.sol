// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

import { CommonV3LiquidityOracle } from "src/CommonV3LiquidityOracle.sol";

import { IWorkerOracle } from "src/interfaces/IWorkerOracle.sol";
// TODO: convert to interface
import { PancakeV3Worker } from "./PancakeV3Worker.sol";

contract PancakeV3WorkerOracle is IWorkerOracle {
  // TODO: maybe move logic in here?
  CommonV3LiquidityOracle public immutable pancakeV3LiquidityOracle;

  constructor(address _pancakeV3LiquidityOracle) {
    pancakeV3LiquidityOracle = CommonV3LiquidityOracle(_pancakeV3LiquidityOracle);
  }

  function getWorkerEquity(address _pancakeV3Worker) external view override returns (uint256 _equityUSD) {
    address _pool = address(PancakeV3Worker(_pancakeV3Worker).pool());
    uint256 _tokenId = PancakeV3Worker(_pancakeV3Worker).nftTokenId();
    return pancakeV3LiquidityOracle.getPositionValueUSD(_pool, _tokenId);
  }
}
