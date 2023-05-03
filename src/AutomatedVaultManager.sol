// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// contracts
import { AutomatedVaultERC20 } from "src/AutomatedVaultERC20.sol";

// interfaces
import { IExecutor } from "src/interfaces/IExecutor.sol";
import { IWorker } from "src/interfaces/IWorker.sol";
import { IAutomatedVaultERC20 } from "src/interfaces/IAutomatedVaultERC20.sol";

contract AutomatedVaultManager is Initializable, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable {
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
  /// @dev execution scope to tell debt manager who executors are acting on behalf of
  address public VAULT_IN_SCOPE;

  event LogOpenVault(address indexed _vaultToken, VaultInfo _vaultInfo);
  event LogDeposit(address indexed _vault, address indexed _depositor, uint256 _amount0, uint256 _amount1);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize() external initializer {
    Ownable2StepUpgradeable.__Ownable2Step_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
  }

  function openVault(string calldata _name, string calldata _symbol, VaultInfo calldata _vaultInfo) external onlyOwner {
    address _vaultToken = address(new AutomatedVaultERC20(_name, _symbol));

    // TODO: sanity check vaultInfo

    vaultInfos[_vaultToken] = _vaultInfo;

    emit LogOpenVault(_vaultToken, _vaultInfo);
  }

  function _getVaultInfo(address _vaultToken) internal view returns (VaultInfo memory _vaultInfo) {
    _vaultInfo = vaultInfos[_vaultToken];
    if (address(_vaultInfo.worker) == address(0)) {
      revert AutomatedVaultManager_VaultNotExist(_vaultToken);
    }
  }

  function _execute(address _vaultToken, IExecutor _executor, bytes memory _params) internal {
    VAULT_IN_SCOPE = _vaultToken;
    _executor.execute(_params);
    VAULT_IN_SCOPE = address(0);
  }

  function deposit(address _vaultToken, uint256 _amount0, uint256 _amount1) external {
    VaultInfo memory _vaultInfo = _getVaultInfo(_vaultToken);

    ERC20(_vaultInfo.worker.token0()).safeTransferFrom(msg.sender, address(_vaultInfo.depositExecutor), _amount0);
    ERC20(_vaultInfo.worker.token1()).safeTransferFrom(msg.sender, address(_vaultInfo.depositExecutor), _amount1);

    _execute(_vaultToken, _vaultInfo.depositExecutor, abi.encode(_amount0, _amount1));

    // TODO: get equity change and mint
    IAutomatedVaultERC20(_vaultToken).mint(msg.sender, 0);

    emit LogDeposit(_vaultToken, msg.sender, _amount0, _amount1);
  }
}
