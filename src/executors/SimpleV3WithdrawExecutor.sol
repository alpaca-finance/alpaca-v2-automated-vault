// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";

// contracts
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";

// interfaces
import { IExecutor } from "src/interfaces/IExecutor.sol";
import { IWorker } from "src/interfaces/IWorker.sol";
import { IBank } from "src/interfaces/IBank.sol";
import { ICommonV3PositionManager } from "src/interfaces/ICommonV3PositionManager.sol";

// libraries
import { Tasks } from "src/libraries/Constants.sol";

contract SimpleV3WithdrawExecutor is IExecutor {
  IBank public immutable bank;
  ICommonV3PositionManager public immutable positionManager;

  constructor(address _bank, address _positionManager) {
    bank = IBank(_bank);
    positionManager = ICommonV3PositionManager(_positionManager);
  }

  function execute(bytes calldata _params) external override returns (bytes memory _result) {
    (ERC20 _vaultToken, PancakeV3Worker _worker, uint256 _sharesToWithdraw, address _recipient) =
      abi.decode(_params, (ERC20, PancakeV3Worker, uint256, address));

    uint256 _tokenId = _worker.nftTokenId();
    (uint128 _liquidity,,,,,,,,,,,) = positionManager.positions(_tokenId);

    _worker.doWork(Tasks.DECREASE, abi.encode(_liquidity * _sharesToWithdraw / _vaultToken.totalSupply()));

    ERC20 _token0 = _worker.token0();
    ERC20 _token1 = _worker.token1();
    _token0.transfer(_recipient, _token0.balanceOf(address(this)));
    _token1.transfer(_recipient, _token1.balanceOf(address(this)));

    return "";
  }
}
