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
import { IAutomatedVaultManager } from "src/interfaces/IAutomatedVaultManager.sol";

contract AutomatedVaultManager is
  Initializable,
  Ownable2StepUpgradeable,
  ReentrancyGuardUpgradeable,
  IAutomatedVaultManager
{
  using SafeTransferLib for ERC20;

  error AutomatedVaultManager_VaultNotExist(address _vaultToken);

  struct VaultInfo {
    IExecutor depositExecutor;
    // packed slot for worker info
    IWorker worker;
    int24 posTickLower;
    int24 posTickUpper;
    // packed slot for reinvest
    address performanceFeeBucket;
    uint16 performanceFeeBps;
  }

  // vault's ERC20 address => vault info
  mapping(address => VaultInfo) public vaultInfos;
  /// @dev execution scope to tell downstream contracts (Bank, Worker, etc.)
  ///      that current executor is acting on behalf of vault and can be trusted
  address public EXECUTOR_IN_SCOPE;

  event LogOpenVault(address indexed _vaultToken, VaultInfo _vaultInfo);
  event LogDeposit(address indexed _vault, address indexed _depositor, DepositTokenParams[] _deposits);

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

  function _execute(IExecutor _executor, bytes memory _params) internal {
    EXECUTOR_IN_SCOPE = address(_executor);
    _executor.execute(_params);
    EXECUTOR_IN_SCOPE = address(0);
  }

  // to support pool with arbitrary number of tokens
  struct DepositTokenParams {
    address token;
    uint256 amount;
  }

  function deposit(address _vaultToken, DepositTokenParams[] calldata _deposits) external {
    VaultInfo memory _vaultInfo = _getVaultInfo(_vaultToken);

    uint256 _depositLength = _deposits.length;
    for (uint256 _i; _i < _depositLength;) {
      ERC20(_deposits[_i].token).safeTransferFrom(msg.sender, address(_vaultInfo.depositExecutor), _deposits[_i].amount);
    }

    _execute(_vaultInfo.depositExecutor, abi.encode(_deposits));

    // TODO: get equity change and mint
    IAutomatedVaultERC20(_vaultToken).mint(msg.sender, 0);

    emit LogDeposit(_vaultToken, msg.sender, _deposits);
  }
}
