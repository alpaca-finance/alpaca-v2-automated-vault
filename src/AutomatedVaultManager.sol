// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";

import { AutomatedVaultERC20 } from "src/AutomatedVaultERC20.sol";

import { IExecutor } from "src/interfaces/IExecutor.sol";
import { IWorker } from "src/interfaces/IWorker.sol";

// TODO: ownable
contract AutomatedVaultManager {
  using SafeTransferLib for ERC20;

  error AutomatedVaultManager_VaultNotExist(address _vaultToken);

  struct VaultInfo {
    IExecutor depositExecutor;
    // packed slot
    int24 posTickLower;
    int24 posTickUpper;
    IWorker worker;
    // packed slot
    uint16 performanceFeeBps;
    address performanceFeeBucket;
  }

  // vault's ERC20 address => vault info
  mapping(address => VaultInfo) public vaultInfos;

  // TODO: onlyOwner
  function openVault(string calldata _name, string calldata _symbol, VaultInfo calldata _vaultInfo) external {
    address vaultToken = address(new AutomatedVaultERC20(_name, _symbol));

    // TODO: sanity check vaultInfo

    vaultInfos[vaultToken] = _vaultInfo;
  }

  function _getVaultInfo(address _vaultToken) internal view returns (VaultInfo memory _vaultInfo) {
    _vaultInfo = vaultInfos[_vaultToken];
    if (address(_vaultInfo.worker) == address(0)) {
      revert AutomatedVaultManager_VaultNotExist(_vaultToken);
    }
  }

  function deposit(address _vaultToken, uint256 _amount0, uint256 _amount1) external {
    VaultInfo memory _vaultInfo = _getVaultInfo(_vaultToken);

    ERC20(_vaultInfo.worker.token0()).safeTransferFrom(msg.sender, address(_vaultInfo.depositExecutor), _amount0);
    ERC20(_vaultInfo.worker.token1()).safeTransferFrom(msg.sender, address(_vaultInfo.depositExecutor), _amount1);

    _vaultInfo.depositExecutor.execute(abi.encode(_amount0, _amount1));

    // TODO: get equity change and mint
  }
}
