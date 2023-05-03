// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";
import { SafeCastLib } from "@solmate/utils/SafeCastLib.sol";
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { IMoneyMarket } from "@alpaca-mm/money-market/interfaces/IMoneyMarket.sol";

// interfaces
import { IAutomatedVaultManager } from "src/interfaces/IAutomatedVaultManager.sol";

contract Bank is Initializable, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable {
  using SafeCastLib for uint256;
  using SafeTransferLib for ERC20;

  error Bank_ExecutorNotInScope();

  IMoneyMarket public moneyMarket;
  IAutomatedVaultManager public vaultManager;

  struct VaultDebtInfo {
    // packed slot
    uint216 debt; // TODO: maybe debt shares if AV accrue interest
    uint40 lastAccrualTime;
  }

  // vault address => token => debt shares
  mapping(address => mapping(address => VaultDebtInfo)) public vaultDebtInfoMap;

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

    moneyMarket = IMoneyMarket(_moneyMarket);
    vaultManager = IAutomatedVaultManager(_vaultManager);
  }

  function borrowOnBehalfOf(address _vaultToken, address _token, uint256 _amount) external onlyExecutorWithinScope {
    // effects
    // safe to use unchecked since overflow amount would revert on borrow or transfer anyway
    unchecked {
      vaultDebtInfoMap[_vaultToken][_token].debt += _amount.safeCastTo216();
    }

    // interactions
    moneyMarket.nonCollatBorrow(_token, _amount);

    ERC20(_token).safeTransfer(_vaultToken, _amount);

    emit LogBorrowOnBehalfOf(_vaultToken, msg.sender, _token, _amount);
  }

  function repayOnBehalfOf(address _vaultToken, address _token, uint256 _amount) external onlyExecutorWithinScope {
    ERC20(_token).safeTransferFrom(_vaultToken, address(this), _amount);

    // will revert underflow if repay more than debt
    vaultDebtInfoMap[_vaultToken][_token].debt -= _amount.safeCastTo216();

    moneyMarket.nonCollatRepay(address(this), _token, _amount);

    emit LogRepayOnBehalfOf(_vaultToken, msg.sender, _token, _amount);
  }
}
