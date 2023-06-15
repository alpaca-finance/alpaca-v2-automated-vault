// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { Clones } from "@openzeppelin/proxy/Clones.sol";

// contracts
import { AutomatedVaultERC20 } from "src/AutomatedVaultERC20.sol";
import { BaseOracle } from "src/oracles/BaseOracle.sol";

// interfaces
import { IExecutor } from "src/interfaces/IExecutor.sol";
import { IVaultOracle } from "src/interfaces/IVaultOracle.sol";
import { IAutomatedVaultERC20 } from "src/interfaces/IAutomatedVaultERC20.sol";
import { IAutomatedVaultManager } from "src/interfaces/IAutomatedVaultManager.sol";

// libraries
import { LibShareUtil } from "src/libraries/LibShareUtil.sol";
import { MAX_BPS } from "src/libraries/Constants.sol";

contract AutomatedVaultManager is
  Initializable,
  Ownable2StepUpgradeable,
  ReentrancyGuardUpgradeable,
  IAutomatedVaultManager
{
  using SafeTransferLib for ERC20;
  using LibShareUtil for uint256;

  error AutomatedVaultManager_VaultNotExist(address _vaultToken);
  error AutomatedVaultManager_WithdrawExceedBalance();
  error AutomatedVaultManager_Unauthorized();
  error AutomatedVaultManager_TooMuchEquityLoss();
  error AutomatedVaultManager_TooMuchLeverage();
  error AutomatedVaultManager_ExceedSlippage();
  error AutomatedVaultManager_BelowMinimumDeposit();
  error AutomatedVaultManager_TooLittleReceived();
  error AutomatedVaultManager_TokenNotAllowed();
  error AutomatedVaultManager_InvalidParams();

  struct VaultInfo {
    address worker;
    address vaultOracle;
    address executor;
    uint256 minimumDeposit;
    uint256 managementFeePerSec;
    uint16 toleranceBps; // acceptable bps of equity deceased after it was manipulated
    uint8 maxLeverage;
  }

  address public vaultTokenImplementation;
  address public managementFeeTreasury;

  // vault's ERC20 address => vault info
  mapping(address => VaultInfo) public vaultInfos;
  mapping(address => mapping(address => bool)) isManager;
  mapping(address => mapping(address => bool)) allowTokens;
  mapping(address => bool) public workerExisted;
  mapping(address => uint256) public vaultFeeLastCollectedAt;
  /// @dev execution scope to tell downstream contracts (Bank, Worker, etc.)
  /// that current executor is acting on behalf of vault and can be trusted
  address public EXECUTOR_IN_SCOPE;

  event LogOpenVault(address indexed _vaultToken, VaultInfo _vaultInfo);
  event LogDeposit(
    address indexed _vaultToken, address indexed _user, DepositTokenParams[] _deposits, uint256 _shareReceived
  );
  event LogWithdraw(address indexed _vaultToken, address indexed _user, uint256 _sharesWithdrawn);
  event LogSetVaultManager(address indexed _vaultToken, address _manager, bool _isOk);
  event LogSetAllowToken(address indexed _vaultToken, address _token, bool _isAllowed);
  event LogSetVaultTokenImplementation(address prevImplementation, address newImplementation);
  event LogSetToleranceBps(address _vaultToken, uint16 _toleranceBps);
  event LogSetMaxLeverage(address _vaultToken, uint8 _maxLeverage);
  event LogSetMinimumDeposit(address _vaultToken, uint256 _minimumDeposit);
  event LogSetManagementFeePerSec(address _vaultToken, uint256 _managementFeePerSec);
  event LogSetMangementFeeTreasury(address _managementFeeTreasury);

  modifier collectManagementFee(address _vaultToken) {
    if (block.timestamp > vaultFeeLastCollectedAt[_vaultToken]) {
      IAutomatedVaultERC20(_vaultToken).mint(managementFeeTreasury, pendingManagementFee(_vaultToken));
      vaultFeeLastCollectedAt[_vaultToken] = block.timestamp;
    }
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(address _vaultTokenImplementation, address _managementFeeTreasury) external initializer {
    Ownable2StepUpgradeable.__Ownable2Step_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    vaultTokenImplementation = _vaultTokenImplementation;
    managementFeeTreasury = _managementFeeTreasury;
  }

  function pendingManagementFee(address _vaultToken) public view returns (uint256 _pendingFee) {
    uint256 _lastCollectedFee = vaultFeeLastCollectedAt[_vaultToken];

    VaultInfo memory _vaultInfo = _getVaultInfo(_vaultToken);
    uint256 _timePassed;
    unchecked {
      _timePassed = block.timestamp - _lastCollectedFee;
    }
    _pendingFee =
      (IAutomatedVaultERC20(_vaultToken).totalSupply() * _vaultInfo.managementFeePerSec * _timePassed) / 1e18;
  }

  function _getVaultInfo(address _vaultToken) internal view returns (VaultInfo memory _vaultInfo) {
    _vaultInfo = vaultInfos[_vaultToken];
    if (_vaultInfo.worker == address(0)) {
      revert AutomatedVaultManager_VaultNotExist(_vaultToken);
    }
  }

  function _pullTokens(address _vaultToken, address _destination, DepositTokenParams[] calldata _deposits) internal {
    uint256 _depositLength = _deposits.length;
    for (uint256 _i; _i < _depositLength;) {
      if (!allowTokens[_vaultToken][_deposits[_i].token]) {
        revert AutomatedVaultManager_TokenNotAllowed();
      }
      ERC20(_deposits[_i].token).safeTransferFrom(msg.sender, _destination, _deposits[_i].amount);
      unchecked {
        ++_i;
      }
    }
  }

  function deposit(address _vaultToken, DepositTokenParams[] calldata _depositParams, uint256 _minReceive)
    external
    collectManagementFee(_vaultToken)
    nonReentrant
    returns (bytes memory _result)
  {
    VaultInfo memory _cachedVaultInfo = _getVaultInfo(_vaultToken);

    _pullTokens(_vaultToken, _cachedVaultInfo.executor, _depositParams);

    ///////////////////////////
    // Executor scope opened //
    ///////////////////////////
    EXECUTOR_IN_SCOPE = _cachedVaultInfo.executor;
    // Accrue interest and reinvest before execute to ensure fair interest and profit distribution
    IExecutor(_cachedVaultInfo.executor).onUpdate(_vaultToken, _cachedVaultInfo.worker);

    (uint256 _totalEquityBefore,) =
      IVaultOracle(_cachedVaultInfo.vaultOracle).getEquityAndDebt(_vaultToken, _cachedVaultInfo.worker);

    _result = IExecutor(_cachedVaultInfo.executor).onDeposit(_cachedVaultInfo.worker, _vaultToken);
    EXECUTOR_IN_SCOPE = address(0);
    ///////////////////////////
    // Executor scope closed //
    ///////////////////////////

    uint256 _equityChanged;
    {
      (uint256 _totalEquityAfter,) =
        IVaultOracle(_cachedVaultInfo.vaultOracle).getEquityAndDebt(_vaultToken, _cachedVaultInfo.worker);
      _equityChanged = _totalEquityAfter - _totalEquityBefore;
    }

    if (_equityChanged < _cachedVaultInfo.minimumDeposit) {
      revert AutomatedVaultManager_BelowMinimumDeposit();
    }

    uint256 _shareRecived =
      _equityChanged.valueToShare(IAutomatedVaultERC20(_vaultToken).totalSupply(), _totalEquityBefore);
    if (_shareRecived < _minReceive) {
      revert AutomatedVaultManager_TooLittleReceived();
    }
    IAutomatedVaultERC20(_vaultToken).mint(msg.sender, _shareRecived);

    emit LogDeposit(_vaultToken, msg.sender, _depositParams, _shareRecived);
  }

  function manage(address _vaultToken, bytes[] calldata _executorParams)
    external
    collectManagementFee(_vaultToken)
    nonReentrant
    returns (bytes[] memory _result)
  {
    // 0. Validate
    if (!isManager[_vaultToken][msg.sender]) {
      revert AutomatedVaultManager_Unauthorized();
    }

    VaultInfo memory _cachedVaultInfo = _getVaultInfo(_vaultToken);

    ///////////////////////////
    // Executor scope opened //
    ///////////////////////////
    EXECUTOR_IN_SCOPE = _cachedVaultInfo.executor;
    // 1. Update the vault
    // Accrue interest and reinvest before execute to ensure fair interest and profit distribution
    IExecutor(_cachedVaultInfo.executor).onUpdate(_vaultToken, _cachedVaultInfo.worker);

    // 2. execute manage
    (uint256 _totalEquityBefore,) =
      IVaultOracle(_cachedVaultInfo.vaultOracle).getEquityAndDebt(_vaultToken, _cachedVaultInfo.worker);

    // Set executor execution scope (worker, vault token) so that we don't have to pass them through multicall
    IExecutor(_cachedVaultInfo.executor).setExecutionScope(_cachedVaultInfo.worker, _vaultToken);
    _result = IExecutor(_cachedVaultInfo.executor).multicall(_executorParams);
    IExecutor(_cachedVaultInfo.executor).sweepToWorker();
    IExecutor(_cachedVaultInfo.executor).setExecutionScope(address(0), address(0));

    EXECUTOR_IN_SCOPE = address(0);
    ///////////////////////////
    // Executor scope closed //
    ///////////////////////////

    // 3. Check equity loss < threshold
    (uint256 _totalEquityAfter, uint256 _debtAfter) =
      IVaultOracle(_cachedVaultInfo.vaultOracle).getEquityAndDebt(_vaultToken, _cachedVaultInfo.worker);

    // _totalEquityAfter  < _totalEquityBefore * _cachedVaultInfo.toleranceBps / MAX_BPS;
    if (_totalEquityAfter * MAX_BPS < _totalEquityBefore * _cachedVaultInfo.toleranceBps) {
      revert AutomatedVaultManager_TooMuchEquityLoss();
    }

    // 4. Check leverage exceed max leverage
    // (debt + equity) / equity > max leverage
    // debt + equity = max leverage * equity
    // debt = (max leverage * equity) - equity
    // debt = (leverage - 1) * equity
    if (_debtAfter > (_cachedVaultInfo.maxLeverage - 1) * _totalEquityAfter) {
      revert AutomatedVaultManager_TooMuchLeverage();
    }
  }

  function setVaultManager(address _vaultToken, address _manager, bool _isOk) external onlyOwner {
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
    collectManagementFee(_vaultToken)
    nonReentrant
    returns (IAutomatedVaultManager.WithdrawResult[] memory _results)
  {
    VaultInfo memory _cachedVaultInfo = _getVaultInfo(_vaultToken);

    // Revert if withdraw shares more than balance
    if (_sharesToWithdraw > IAutomatedVaultERC20(_vaultToken).balanceOf(msg.sender)) {
      revert AutomatedVaultManager_WithdrawExceedBalance();
    }

    ///////////////////////////
    // Executor scope opened //
    ///////////////////////////
    EXECUTOR_IN_SCOPE = _cachedVaultInfo.executor;

    // Accrue interest and reinvest before execute to ensure fair interest and profit distribution
    IExecutor(_cachedVaultInfo.executor).onUpdate(_vaultToken, _cachedVaultInfo.worker);

    (uint256 _totalEquityBefore,) =
      IVaultOracle(_cachedVaultInfo.vaultOracle).getEquityAndDebt(_vaultToken, _cachedVaultInfo.worker);

    // Execute withdraw
    // Executor should send withdrawn funds back here to check slippage
    _results = IExecutor(_cachedVaultInfo.executor).onWithdraw(_cachedVaultInfo.worker, _vaultToken, _sharesToWithdraw);

    EXECUTOR_IN_SCOPE = address(0);
    ///////////////////////////
    // Executor scope closed //
    ///////////////////////////

    // Check equity changed shouldn't exceed shares withdrawn proportion
    // e.g. equityBefore = 100 USD, withdraw 10% of shares, equity shouldn't decrease more than 10 USD
    uint256 _equityChanged;
    {
      (uint256 _totalEquityAfter,) =
        IVaultOracle(_cachedVaultInfo.vaultOracle).getEquityAndDebt(_vaultToken, _cachedVaultInfo.worker);
      _equityChanged = _totalEquityBefore - _totalEquityAfter;
    }
    // // +1 to account for possible precision loss
    // uint256 _maxEquityChange =
    //   _sharesToWithdraw * _totalEquityBefore / IAutomatedVaultERC20(_vaultToken).totalSupply() + 1;
    // if (_equityChanged > _maxEquityChange) {
    //   revert AutomatedVaultManager_TooMuchEquityLoss();
    // }

    // Burn shares per requested amount before transfer out
    IAutomatedVaultERC20(_vaultToken).burn(msg.sender, _sharesToWithdraw);

    // Transfer withdrawn funds to user
    // Tokens should be transferred from executor to here during `onWithdraw`
    {
      uint256 _len = _results.length;
      uint256 _minAmountOutsLen = _minAmountOuts.length;
      address _token;
      uint256 _amount;
      for (uint256 _i; _i < _len;) {
        _token = _results[_i].token;
        _amount = _results[_i].amount;
        // Check slippage
        for (uint256 _j; _j < _minAmountOutsLen;) {
          if (_minAmountOuts[_j].token == _token && _minAmountOuts[_j].minAmountOut > _amount) {
            revert AutomatedVaultManager_ExceedSlippage();
          }
          unchecked {
            ++_j;
          }
        }
        ERC20(_token).safeTransfer(msg.sender, _amount);
        unchecked {
          ++_i;
        }
      }
    }

    emit LogWithdraw(_vaultToken, msg.sender, _sharesToWithdraw);
  }

  /// =========================
  /// Admin functions
  /// =========================

  function openVault(string calldata _name, string calldata _symbol, VaultInfo calldata _vaultInfo)
    external
    onlyOwner
    returns (address _vaultToken)
  {
    // Prevent duplicate worker between vaults
    if (workerExisted[_vaultInfo.worker]) {
      revert AutomatedVaultManager_InvalidParams();
    }
    _validateToleranceBps(_vaultInfo.toleranceBps);
    _validateMaxLeverage(_vaultInfo.maxLeverage);
    _validateMinimumDeposit(_vaultInfo.minimumDeposit);
    // Sanity check oracle
    BaseOracle(_vaultInfo.vaultOracle).maxPriceAge();
    // Sanity check executor
    if (IExecutor(_vaultInfo.executor).vaultManager() != address(this)) {
      revert AutomatedVaultManager_InvalidParams();
    }

    // Deploy vault token with ERC-1167 minimal proxy
    _vaultToken = Clones.clone(vaultTokenImplementation);
    AutomatedVaultERC20(_vaultToken).initialize(_name, _symbol);

    // Update states
    vaultFeeLastCollectedAt[_vaultToken] = block.timestamp;
    vaultInfos[_vaultToken] = _vaultInfo;
    workerExisted[_vaultInfo.worker] = true;

    emit LogOpenVault(_vaultToken, _vaultInfo);
  }

  function setVaultTokenImplementation(address _implementation) external onlyOwner {
    emit LogSetVaultTokenImplementation(vaultTokenImplementation, _implementation);
    vaultTokenImplementation = _implementation;
  }

  function setAllowToken(address _vaultToken, address _token, bool _isAllowed) external onlyOwner {
    // sanity check, should revert if vault not opened
    if (vaultInfos[_vaultToken].worker == address(0)) {
      revert AutomatedVaultManager_VaultNotExist(_vaultToken);
    }
    allowTokens[_vaultToken][_token] = _isAllowed;

    emit LogSetAllowToken(_vaultToken, _token, _isAllowed);
  }

  function setToleranceBps(address _vaultToken, uint16 _toleranceBps) external onlyOwner {
    _validateToleranceBps(_toleranceBps);
    vaultInfos[_vaultToken].toleranceBps = _toleranceBps;

    emit LogSetToleranceBps(_vaultToken, _toleranceBps);
  }

  function setMaxLeverage(address _vaultToken, uint8 _maxLeverage) external onlyOwner {
    _validateMaxLeverage(_maxLeverage);
    vaultInfos[_vaultToken].maxLeverage = _maxLeverage;

    emit LogSetMaxLeverage(_vaultToken, _maxLeverage);
  }

  function setMinimumDeposit(address _vaultToken, uint256 _minimumDeposit) external onlyOwner {
    _validateMinimumDeposit(_minimumDeposit);
    vaultInfos[_vaultToken].minimumDeposit = _minimumDeposit;

    emit LogSetMinimumDeposit(_vaultToken, _minimumDeposit);
  }

  function setManagementFeePerSec(address _vaultToken, uint256 _managementFeePerSec) external onlyOwner {
    vaultInfos[_vaultToken].managementFeePerSec = _managementFeePerSec;

    emit LogSetManagementFeePerSec(_vaultToken, _managementFeePerSec);
  }

  function setManagementFeeTreasury(address _managementFeeTreasury) external onlyOwner {
    managementFeeTreasury = _managementFeeTreasury;

    emit LogSetMangementFeeTreasury(_managementFeeTreasury);
  }

  /// @dev Valid value range: 9500 <= toleranceBps <= 10000
  function _validateToleranceBps(uint16 _toleranceBps) internal pure {
    if (_toleranceBps > MAX_BPS || _toleranceBps < 9500) {
      revert AutomatedVaultManager_InvalidParams();
    }
  }

  /// @dev Valid value range: 1 <= maxLeverage <= 10
  function _validateMaxLeverage(uint8 _maxLeverage) internal pure {
    if (_maxLeverage > 10 || _maxLeverage < 1) {
      revert AutomatedVaultManager_InvalidParams();
    }
  }

  function _validateMinimumDeposit(uint256 _minimumDeposit) internal pure {
    if (_minimumDeposit < 1e18) {
      revert AutomatedVaultManager_InvalidParams();
    }
  }
}
