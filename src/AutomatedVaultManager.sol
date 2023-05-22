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
import { IWorker } from "src/interfaces/IWorker.sol";
import { IExecutor } from "src/interfaces/IExecutor.sol";
import { IVaultOracle } from "src/interfaces/IVaultOracle.sol";
import { IAutomatedVaultERC20 } from "src/interfaces/IAutomatedVaultERC20.sol";
import { IAutomatedVaultManager } from "src/interfaces/IAutomatedVaultManager.sol";

// libraries
import { LibShareUtil } from "src/libraries/LibShareUtil.sol";

contract AutomatedVaultManager is
  Initializable,
  Ownable2StepUpgradeable,
  ReentrancyGuardUpgradeable,
  IAutomatedVaultManager
{
  using SafeTransferLib for ERC20;
  using LibShareUtil for uint256;

  error AutomatedVaultManager_VaultNotExist(address _vaultToken);
  error AutomatedVaultManager_InvalidParams();

  struct VaultInfo {
    address worker;
    address vaultOracle;
    address depositExecutor;
    address withdrawExecutor;
    address updateExecutor;
  }

  // vault's ERC20 address => vault info
  mapping(address => VaultInfo) public vaultInfos;
  /// @dev execution scope to tell downstream contracts (Bank, Worker, etc.)
  /// that current executor is acting on behalf of vault and can be trusted
  address public EXECUTOR_IN_SCOPE;

  event LogOpenVault(address indexed _vaultToken, VaultInfo _vaultInfo);
  event LogDeposit(address indexed _vaultToken, address indexed _user, DepositTokenParams[] _deposits);
  event LogWithdraw(address indexed _vaultToken, address indexed _user, uint256 _sharesWithdrawn);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize() external initializer {
    Ownable2StepUpgradeable.__Ownable2Step_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
  }

  function openVault(string calldata _name, string calldata _symbol, VaultInfo calldata _vaultInfo)
    external
    onlyOwner
    returns (address _vaultToken)
  {
    // TODO: use minimal proxy to deploy
    _vaultToken = address(new AutomatedVaultERC20(_name, _symbol));

    // TODO: sanity check vaultInfo

    vaultInfos[_vaultToken] = _vaultInfo;

    emit LogOpenVault(_vaultToken, _vaultInfo);
  }

  function _getVaultInfo(address _vaultToken) internal view returns (VaultInfo memory _vaultInfo) {
    _vaultInfo = vaultInfos[_vaultToken];
    if (_vaultInfo.worker == address(0)) {
      revert AutomatedVaultManager_VaultNotExist(_vaultToken);
    }
  }

  function _execute(address _executor, bytes memory _params) internal returns (bytes memory _result) {
    EXECUTOR_IN_SCOPE = _executor;
    _result = IExecutor(_executor).execute(_params);
    EXECUTOR_IN_SCOPE = address(0);
  }

  // TODO: slippage control
  // TODO: remove executor params?
  function deposit(address _vaultToken, DepositTokenParams[] calldata _deposits, bytes calldata _executorParams)
    external
    nonReentrant
    returns (bytes memory _result)
  {
    VaultInfo memory _cachedVaultInfo = _getVaultInfo(_vaultToken);

    uint256 _depositLength = _deposits.length;
    for (uint256 _i; _i < _depositLength;) {
      ERC20(_deposits[_i].token).safeTransferFrom(msg.sender, _cachedVaultInfo.depositExecutor, _deposits[_i].amount);
      unchecked {
        ++_i;
      }
    }

    // Accrue interest and reinvest before execute to ensure fair interest and profit distribution
    IExecutor(_cachedVaultInfo.updateExecutor).execute(abi.encode(_vaultToken, _cachedVaultInfo.worker));

    uint256 _totalEquityBefore =
      IVaultOracle(_cachedVaultInfo.vaultOracle).getEquity(_vaultToken, _cachedVaultInfo.worker);

    _result =
      _execute(_cachedVaultInfo.depositExecutor, abi.encode(_cachedVaultInfo.worker, _deposits, _executorParams));

    uint256 _equityChanged =
      IVaultOracle(_cachedVaultInfo.vaultOracle).getEquity(_vaultToken, _cachedVaultInfo.worker) - _totalEquityBefore;

    IAutomatedVaultERC20(_vaultToken).mint(
      msg.sender, _equityChanged.valueToShare(IAutomatedVaultERC20(_vaultToken).totalSupply(), _totalEquityBefore)
    );

    emit LogDeposit(_vaultToken, msg.sender, _deposits);
  }

  // TODO: slippage control
  function withdraw(address _vaultToken, uint256 _sharesToWithdraw)
    external
    nonReentrant
    returns (bytes memory _result)
  {
    if (_sharesToWithdraw > IAutomatedVaultERC20(_vaultToken).balanceOf(msg.sender)) {
      revert AutomatedVaultManager_InvalidParams();
    }

    VaultInfo memory _cachedVaultInfo = _getVaultInfo(_vaultToken);

    // Accrue interest and reinvest before execute to ensure fair interest and profit distribution
    IExecutor(_cachedVaultInfo.updateExecutor).execute(abi.encode(_vaultToken, _cachedVaultInfo.worker));

    uint256 _totalEquityBefore =
      IVaultOracle(_cachedVaultInfo.vaultOracle).getEquity(_vaultToken, _cachedVaultInfo.worker);

    _result = _execute(
      _cachedVaultInfo.withdrawExecutor, abi.encode(_vaultToken, _cachedVaultInfo.worker, _sharesToWithdraw, msg.sender)
    );

    uint256 _equityChanged =
      _totalEquityBefore - IVaultOracle(_cachedVaultInfo.vaultOracle).getEquity(_vaultToken, _cachedVaultInfo.worker);

    uint256 _actualSharesWithdrawn =
      _equityChanged.valueToShare(IAutomatedVaultERC20(_vaultToken).totalSupply(), _totalEquityBefore);

    IAutomatedVaultERC20(_vaultToken).burn(msg.sender, _actualSharesWithdrawn);

    emit LogWithdraw(_vaultToken, msg.sender, _actualSharesWithdrawn);
  }
}
