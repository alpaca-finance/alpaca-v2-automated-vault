// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

import { AutomatedVaultManager, ERC20 } from "src/AutomatedVaultManager.sol";
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { PancakeV3VaultOracle } from "src/oracles/PancakeV3VaultOracle.sol";
import { Bank } from "src/Bank.sol";
import { ICommonV3Pool } from "src/interfaces/ICommonV3Pool.sol";

import { LibTickMath } from "src/libraries/LibTickMath.sol";
import { LibSqrtPriceX96 } from "src/libraries/LibSqrtPriceX96.sol";
import { LibLiquidityAmounts } from "src/libraries/LibLiquidityAmounts.sol";

import { IVaultReader } from "src/interfaces/IVaultReader.sol";

contract VaultReader is IVaultReader {
  AutomatedVaultManager internal immutable automatedVaultManager;
  PancakeV3VaultOracle internal immutable pancakeV3VaultOracle;
  Bank internal immutable bank;

  constructor(address _automatedVaultManager, address _bank, address _pancakeV3VaultOracle) {
    automatedVaultManager = AutomatedVaultManager(_automatedVaultManager);
    bank = Bank(_bank);
    pancakeV3VaultOracle = PancakeV3VaultOracle(_pancakeV3VaultOracle);
  }

  function getVaultSummary(address _vaultToken) external view returns (VaultSummary memory _vaultSummary) {
    uint256 _farmed0Amount;
    uint256 _farmed1Amount;
    uint256 _debt0Amount;
    uint256 _debt1Amount;
    uint256 _priceLower;
    uint256 _priceUpper;

    (address _worker,,,,,,,) = automatedVaultManager.vaultInfos(_vaultToken);
    ERC20 _token0 = PancakeV3Worker(_worker).token0();
    ERC20 _token1 = PancakeV3Worker(_worker).token1();
    uint256 _tokenId = PancakeV3Worker(_worker).nftTokenId();
    (uint160 _poolSqrtPriceX96,,,,,,) = ICommonV3Pool(PancakeV3Worker(_worker).pool()).slot0();

    (, _debt0Amount) = bank.getVaultDebt(_vaultToken, address(_token0));
    (, _debt1Amount) = bank.getVaultDebt(_vaultToken, address(_token1));
    (,,,,, int24 _tickLower, int24 _tickUpper, uint128 _liquidity,,,,) =
      PancakeV3Worker(_worker).nftPositionManager().positions(_tokenId);
    {
      (_farmed0Amount, _farmed1Amount) = LibLiquidityAmounts.getAmountsForLiquidity(
        _poolSqrtPriceX96,
        LibTickMath.getSqrtRatioAtTick(_tickLower),
        LibTickMath.getSqrtRatioAtTick(_tickUpper),
        _liquidity
      );

      _priceLower = _tickToPrice(_tickLower, _token0.decimals(), _token1.decimals());
      _priceUpper = _tickToPrice(_tickUpper, _token0.decimals(), _token1.decimals());
    }

    _vaultSummary = VaultSummary({
      token0price: pancakeV3VaultOracle.getTokenPrice(address(_token0)),
      token1price: pancakeV3VaultOracle.getTokenPrice(address(_token1)),
      token0Undeployed: _token0.balanceOf(_worker),
      token1Undeployed: _token1.balanceOf(_worker),
      token0Farmed: _farmed0Amount,
      token1Farmed: _farmed1Amount,
      token0Debt: _debt0Amount,
      token1Debt: _debt1Amount,
      lowerPrice: _priceLower,
      upperPrice: _priceUpper
    });
  }

  function _tickToPrice(int24 _tick, uint256 _token0Decimals, uint256 _token1Decimals)
    public
    pure
    returns (uint256 _price)
  {
    // tick => sqrtPriceX96 => price
    uint160 _sqrtPriceX96 = LibTickMath.getSqrtRatioAtTick(_tick);
    _price = LibSqrtPriceX96.decodeSqrtPriceX96(_sqrtPriceX96, _token0Decimals, _token1Decimals);
  }
}
