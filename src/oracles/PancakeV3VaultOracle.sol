// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

import { CommonV3LiquidityOracle } from "src/oracles/CommonV3LiquidityOracle.sol";

import { IVaultOracle } from "src/interfaces/IVaultOracle.sol";
// TODO: convert to interface
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";

contract PancakeV3VaultOracle is IVaultOracle {
  // TODO: maybe move logic in here?
  CommonV3LiquidityOracle public immutable pancakeV3LiquidityOracle;

  constructor(address _pancakeV3LiquidityOracle) {
    pancakeV3LiquidityOracle = CommonV3LiquidityOracle(_pancakeV3LiquidityOracle);
  }

  function getEquity(address _pancakeV3Worker) external view override returns (uint256 _equityUSD) {
    // TODO: include debt in pricing
    address _pool = address(PancakeV3Worker(_pancakeV3Worker).pool());
    uint256 _tokenId = PancakeV3Worker(_pancakeV3Worker).nftTokenId();
    if (_tokenId == 0) return 0;
    return pancakeV3LiquidityOracle.getPositionValueUSD(_pool, _tokenId);
  }
}
