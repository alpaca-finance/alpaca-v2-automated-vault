// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";
import { SafeCastLib } from "@solmate/utils/SafeCastLib.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { IMoneyMarket } from "@alpaca-mm/money-market/interfaces/IMoneyMarket.sol";

// contracts
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";

// libraries
import { LibShareUtil } from "src/libraries/LibShareUtil.sol";

contract Bank is Initializable, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable {
  using SafeCastLib for uint256;
  using SafeTransferLib for ERC20;
  using LibShareUtil for uint256;
  using EnumerableSet for EnumerableSet.AddressSet;

  error Bank_ExecutorNotInScope();
  error Bank_RepayMoreThanDebt();

  IMoneyMarket public moneyMarket;
  AutomatedVaultManager public vaultManager;

  // vault token => list of borrowed tokens
  mapping(address => EnumerableSet.AddressSet) internal vaultDebtTokens;
  // vault token => borrowed token => debt shares
  mapping(address => mapping(address => uint256)) public vaultDebtShares;
  // token => total debt shares
  mapping(address => uint256) public tokenDebtShares;

  event LogBorrowOnBehalfOf(address indexed _vaultToken, address indexed _executor, address _token, uint256 _amount);
  event LogRepayOnBehalfOf(address indexed _vaultToken, address indexed _executor, address _token, uint256 _amount);

  modifier onlyExecutorWithinScope() {
    if (msg.sender != vaultManager.EXECUTOR_IN_SCOPE()) revert Bank_ExecutorNotInScope();
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(address _moneyMarket, address _vaultManager) external initializer {
    Ownable2StepUpgradeable.__Ownable2Step_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    // Sanity check
    IMoneyMarket(_moneyMarket).getMinDebtSize();
    AutomatedVaultManager(_vaultManager).vaultTokenImplementation();

    moneyMarket = IMoneyMarket(_moneyMarket);
    vaultManager = AutomatedVaultManager(_vaultManager);
  }

  function accrueInterest(address _vaultToken) external {
    uint256 _length = vaultDebtTokens[_vaultToken].length();
    for (uint256 _i; _i < _length;) {
      moneyMarket.accrueInterest(vaultDebtTokens[_vaultToken].at(_i));
      unchecked {
        ++_i;
      }
    }
  }

  function getVaultDebt(address _vaultToken, address _token)
    external
    view
    returns (uint256 _debtShares, uint256 _debtAmount)
  {
    _debtShares = vaultDebtShares[_vaultToken][_token];
    // NOTE: must accrue interest on money market before calculate shares to correctly reflect debt
    _debtAmount =
      _debtShares.shareToValue(moneyMarket.getNonCollatAccountDebt(address(this), _token), tokenDebtShares[_token]);
  }

  function borrowOnBehalfOf(address _vaultToken, address _token, uint256 _amount) external onlyExecutorWithinScope {
    // Cache to save gas
    IMoneyMarket _moneyMarket = moneyMarket;
    // Accure interest
    _moneyMarket.accrueInterest(_token);

    // Effects
    // Cache to save gas
    uint256 _cachedTokenDebtShares = tokenDebtShares[_token];
    // NOTE: must accrue interest on money market before calculate shares to correctly reflect debt
    // Round up in protocol favor
    uint256 _debtSharesToAdd = _amount.valueToShareRoundingUp(
      _cachedTokenDebtShares, _moneyMarket.getNonCollatAccountDebt(address(this), _token)
    );
    // Add to borrowed token list if borrow for first time
    if (_cachedTokenDebtShares == 0) {
      vaultDebtTokens[_vaultToken].add(_token);
    }
    // Safe to use unchecked since overflow amount would revert on borrow or transfer anyway
    unchecked {
      tokenDebtShares[_token] = _cachedTokenDebtShares + _debtSharesToAdd;
      vaultDebtShares[_vaultToken][_token] += _debtSharesToAdd;
    }

    // Interactions
    // Non-collat borrow from money market
    _moneyMarket.nonCollatBorrow(_token, _amount);
    // Forward tokens to executor
    ERC20(_token).safeTransfer(msg.sender, _amount);

    emit LogBorrowOnBehalfOf(_vaultToken, msg.sender, _token, _amount);
  }

  function repayOnBehalfOf(address _vaultToken, address _token, uint256 _amount) external onlyExecutorWithinScope {
    // Transfer in first to early revert if insufficient balance
    ERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

    // Cache to save gas
    IMoneyMarket _moneyMarket = moneyMarket;
    // Accure interest
    _moneyMarket.accrueInterest(_token);

    // Effects
    // Cache to save gas
    uint256 _cachedTokenDebtShares = tokenDebtShares[_token];
    // NOTE: must accrue interest on money market before calculate shares to correctly reflect debt
    // Round down in protocol favor
    uint256 _debtSharesToDecrease =
      _amount.valueToShare(_cachedTokenDebtShares, _moneyMarket.getNonCollatAccountDebt(address(this), _token));
    if (_debtSharesToDecrease > _cachedTokenDebtShares) {
      revert Bank_RepayMoreThanDebt();
    }
    // Safe to unchecked, already checked above
    unchecked {
      tokenDebtShares[_token] = _cachedTokenDebtShares - _debtSharesToDecrease;
      // Remove from borrowed token list if repay all
      if (_cachedTokenDebtShares - _debtSharesToDecrease == 0) {
        vaultDebtTokens[_vaultToken].remove(_token);
      }
    }
    vaultDebtShares[_vaultToken][_token] -= _debtSharesToDecrease;

    // Interactions
    ERC20(_token).safeApprove(address(_moneyMarket), _amount);
    // Non-collat repay money market, repay for itself
    _moneyMarket.nonCollatRepay(address(this), _token, _amount);

    emit LogRepayOnBehalfOf(_vaultToken, msg.sender, _token, _amount);
  }
}
