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
  error AutomatedVaultManager_Unauthorized();
  error AutomatedVaultManager_TooMuchEquityLoss();
  error AutomatedVaultManager_TooMuchLeverage();
  error AutomatedVaultManager_ExceedSlippage();

  struct VaultInfo {
    address worker;
    address vaultOracle;
    address executor;
    uint16 toleranceBps; // acceptable bps of equity deceased after it was manipulated
    uint8 maxLeverage;
  }

  // vault's ERC20 address => vault info
  mapping(address => VaultInfo) public vaultInfos;
  mapping(address => mapping(address => bool)) isManager;
  /// @dev execution scope to tell downstream contracts (Bank, Worker, etc.)
  /// that current executor is acting on behalf of vault and can be trusted
  address public EXECUTOR_IN_SCOPE;

  event LogOpenVault(address indexed _vaultToken, VaultInfo _vaultInfo);
  event LogDeposit(address indexed _vaultToken, address indexed _user, DepositTokenParams[] _deposits);
  event LogWithdraw(address indexed _vaultToken, address indexed _user, uint256 _sharesWithdrawn);
  event LogSetVaultManager(address indexed _vaultToken, address _manager, bool _isOk);

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

  function _pullTokens(address _destination, DepositTokenParams[] calldata _deposits) internal {
    uint256 _depositLength = _deposits.length;
    for (uint256 _i; _i < _depositLength;) {
      ERC20(_deposits[_i].token).safeTransferFrom(msg.sender, _destination, _deposits[_i].amount);
      unchecked {
        ++_i;
      }
    }
  }

  // TODO: slippage control
  // TODO: tiny shares
  function deposit(address _vaultToken, DepositTokenParams[] calldata _depositParams)
    external
    returns (bytes memory _result)
  {
    VaultInfo memory _cachedVaultInfo = _getVaultInfo(_vaultToken);
    // todo: check if vault is opened;

    _pullTokens(_cachedVaultInfo.executor, _depositParams);

    EXECUTOR_IN_SCOPE = _cachedVaultInfo.executor;
    // Accrue interest and reinvest before execute to ensure fair interest and profit distribution
    IExecutor(_cachedVaultInfo.executor).onUpdate(_vaultToken, _cachedVaultInfo.worker);

    (uint256 _totalEquityBefore,) =
      IVaultOracle(_cachedVaultInfo.vaultOracle).getEquityAndDebt(_vaultToken, _cachedVaultInfo.worker);

    // todo: send deposit params to executor
    _result = IExecutor(_cachedVaultInfo.executor).onDeposit(_cachedVaultInfo.worker, _vaultToken);
    EXECUTOR_IN_SCOPE = address(0);

    uint256 _equityChanged;
    {
      (uint256 _totalEquityAfter,) =
        IVaultOracle(_cachedVaultInfo.vaultOracle).getEquityAndDebt(_vaultToken, _cachedVaultInfo.worker);
      _equityChanged = _totalEquityAfter - _totalEquityBefore;
    }

    IAutomatedVaultERC20(_vaultToken).mint(
      msg.sender, _equityChanged.valueToShare(IAutomatedVaultERC20(_vaultToken).totalSupply(), _totalEquityBefore)
    );

    emit LogDeposit(_vaultToken, msg.sender, _depositParams);
  }

  function manage(address _vaultToken, bytes[] calldata _executorParams)
    external
    nonReentrant
    returns (bytes[] memory _result)
  {
    // 0. Validate
    if (!isManager[_vaultToken][msg.sender]) {
      revert AutomatedVaultManager_Unauthorized();
    }

    VaultInfo memory _cachedVaultInfo = _getVaultInfo(_vaultToken);
    // 1. Update the vault
    EXECUTOR_IN_SCOPE = _cachedVaultInfo.executor;
    // Accrue interest and reinvest before execute to ensure fair interest and profit distribution
    IExecutor(_cachedVaultInfo.executor).onUpdate(_vaultToken, _cachedVaultInfo.worker);

    // 2. execute manage
    (uint256 _totalEquityBefore,) =
      IVaultOracle(_cachedVaultInfo.vaultOracle).getEquityAndDebt(_vaultToken, _cachedVaultInfo.worker);

    _result = IExecutor(_cachedVaultInfo.executor).multicall(_executorParams);
    EXECUTOR_IN_SCOPE = address(0);

    // 3. Check equity loss < threshold
    (uint256 _totalEquityAfter, uint256 _debtAfter) =
      IVaultOracle(_cachedVaultInfo.vaultOracle).getEquityAndDebt(_vaultToken, _cachedVaultInfo.worker);

    // _totalEquityAfter  < _totalEquityBefore * _cachedVaultInfo.toleranceBps / MAX_BPS;
    if (_totalEquityAfter * 10000 < _totalEquityBefore * _cachedVaultInfo.toleranceBps) {
      revert AutomatedVaultManager_TooMuchEquityLoss();
    }

    // 4. Check leverage exceed max leverage
    // (debt + equity) / equity > max leverage
    // debt + equity = max leverage * equity
    // debt = (max leverage * equity) - equity
    // debt = (leverage - 1) * equity
    if ((_debtAfter) > (_cachedVaultInfo.maxLeverage - 1) * _totalEquityAfter) {
      revert AutomatedVaultManager_TooMuchLeverage();
    }
  }

  function setVaultManagers(address _vaultToken, address _manager, bool _isOk) external onlyOwner {
    isManager[_vaultToken][_manager] = _isOk;
    emit LogSetVaultManager(_vaultToken, _manager, _isOk);
  }

  struct WithdrawSlippage {
    address token;
    uint256 minAmountOut;
  }

  // TODO: withdrawal fee
  function withdraw(address _vaultToken, uint256 _sharesToWithdraw, WithdrawSlippage[] calldata _minAmountOuts)
    external
    nonReentrant
  {
    // Revert if withdraw shares more than balance
    if (_sharesToWithdraw > IAutomatedVaultERC20(_vaultToken).balanceOf(msg.sender)) {
      revert AutomatedVaultManager_InvalidParams();
    }

    VaultInfo memory _cachedVaultInfo = _getVaultInfo(_vaultToken);

    /////////////////////////
    // Open executor scope //
    /////////////////////////
    EXECUTOR_IN_SCOPE = _cachedVaultInfo.executor;

    // Accrue interest and reinvest before execute to ensure fair interest and profit distribution
    IExecutor(_cachedVaultInfo.executor).onUpdate(_vaultToken, _cachedVaultInfo.worker);

    (uint256 _totalEquityBefore,) =
      IVaultOracle(_cachedVaultInfo.vaultOracle).getEquityAndDebt(_vaultToken, _cachedVaultInfo.worker);

    // Execute withdraw
    // Executor should send withdrawn funds back here to check slippage
    IAutomatedVaultManager.WithdrawResult[] memory _results =
      IExecutor(_cachedVaultInfo.executor).onWithdraw(_cachedVaultInfo.worker, _vaultToken, _sharesToWithdraw);

    //////////////////////////
    // Close executor scope //
    //////////////////////////
    EXECUTOR_IN_SCOPE = address(0);

    // Check slippage
    uint256 _len = _minAmountOuts.length;
    for (uint256 _i; _i < _len;) {
      if (ERC20(_minAmountOuts[_i].token).balanceOf(address(this)) < _minAmountOuts[_i].minAmountOut) {
        revert AutomatedVaultManager_ExceedSlippage();
      }
      unchecked {
        ++_i;
      }
    }

    // Transfer withdrawn funds to user
    // Tokens should be transferred from executor to here during `onWithdraw`
    _len = _results.length;
    for (uint256 _i; _i < _len;) {
      ERC20(_results[_i].token).safeTransfer(msg.sender, _results[_i].amount);
      unchecked {
        ++_i;
      }
    }

    // Check equity changed shouldn't exceed shares withdrawn proportion
    uint256 _equityChanged;
    {
      (uint256 _totalEquityAfter,) =
        IVaultOracle(_cachedVaultInfo.vaultOracle).getEquityAndDebt(_vaultToken, _cachedVaultInfo.worker);
      _equityChanged = _totalEquityBefore - _totalEquityAfter;
    }
    uint256 _maxEquityChange = _sharesToWithdraw * _totalEquityBefore / IAutomatedVaultERC20(_vaultToken).totalSupply();
    if (_equityChanged > _maxEquityChange) {
      revert AutomatedVaultManager_TooMuchEquityLoss();
    }

    // Burn shares per requested amount
    IAutomatedVaultERC20(_vaultToken).burn(msg.sender, _sharesToWithdraw);

    emit LogWithdraw(_vaultToken, msg.sender, _sharesToWithdraw);
  }
}
