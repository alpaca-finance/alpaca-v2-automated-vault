// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { PCSV3Executor01 } from "src/executors/PCSV3Executor01.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";

contract ManageScript is BaseScript {
  function run() public {
    address _vaultToken = 0x5dc672d3528535a97173AeD4671ccd2E5f627e44;
    // tick rage +- 20% from 240.887 USDT per BNB
    int24 _tickLower = -57080;
    int24 _tickUpper = -52610;

    uint256 _amount0In = 5 ether;

    // deposit input
    AutomatedVaultManager.TokenAmount[] memory _depositParams = new AutomatedVaultManager.TokenAmount[](1);
    _depositParams[0] = AutomatedVaultManager.TokenAmount({ token: usdt, amount: _amount0In });

    // maange input
    bytes[] memory executorData = new bytes[](3);
    executorData[0] = _getBorrowTokenBytes(usdt, 3 ether);
    executorData[1] = _getTransferToWorkerBytes(usdt, 3 ether);
    executorData[2] = _getOpenPositionBytes(_tickLower, _tickUpper, 8 ether, 0);

    vm.startBroadcast(deployerPrivateKey);

    ERC20(usdt).approve(automatedVaultManager, _amount0In);
    AutomatedVaultManager(automatedVaultManager).deposit(_vaultToken, _depositParams, 0);

    AutomatedVaultManager(automatedVaultManager).manage(_vaultToken, executorData);

    vm.stopBroadcast();
  }

  function _getOpenPositionBytes(int24 _tickLower, int24 _tickUpper, uint256 _amount0, uint256 _amount1)
    internal
    pure
    returns (bytes memory _data)
  {
    _data = abi.encodeCall(PCSV3Executor01.openPosition, (_tickLower, _tickUpper, _amount0, _amount1));
  }

  function _getBorrowTokenBytes(address _token, uint256 _amount) internal pure returns (bytes memory _data) {
    _data = abi.encodeCall(PCSV3Executor01.borrow, (_token, _amount));
  }

  function _getTransferToWorkerBytes(address _token, uint256 _amount) internal pure returns (bytes memory _data) {
    _data = abi.encodeCall(PCSV3Executor01.transferToWorker, (_token, _amount));
  }

  function _getClosePositionBytes() internal pure returns (bytes memory _data) {
    _data = abi.encodeCall(PCSV3Executor01.closePosition, ());
  }
}
