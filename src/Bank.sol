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

  error Bank_Unauthorized();
  error Bank_NotInExecutionScope();

  IMoneyMarket public moneyMarket;
  IAutomatedVaultManager public vaultManager;

  struct VaultDebtInfo {
    // packed slot
    uint216 debt; // TODO: maybe debt shares if AV accrue interest
    uint40 lastAccrualTime;
  }

  // vault address => token => debt shares
  mapping(address => mapping(address => VaultDebtInfo)) public vaultDebtInfoMap;
  mapping(address => bool) public executorsOk;

  event LogSetExecutorsOk(address[] _executors, bool _isOk);
  event LogBorrowOnBehalfOf(address indexed _vault, address indexed _executor, address _token, uint256 _amount);
  event LogRepayOnBehalfOf(address indexed _vault, address indexed _executor, address _token, uint256 _amount);

  modifier onlyExecutor() {
    if (!executorsOk[msg.sender]) revert Bank_Unauthorized();
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

  function setExecutorsOk(address[] calldata _executors, bool _isOk) external onlyOwner {
    uint256 _len = _executors.length;
    for (uint256 _i; _i < _len;) {
      executorsOk[_executors[_i]] = _isOk;
      unchecked {
        ++_i;
      }
    }
    emit LogSetExecutorsOk(_executors, _isOk);
  }

  function _getVaultInScope() internal view returns (address _vault) {
    _vault = vaultManager.VAULT_IN_SCOPE();
    if (_vault == address(0)) revert Bank_NotInExecutionScope();
  }

  function borrowOnBehalfOf(address _token, uint256 _amount) external onlyExecutor {
    // checks
    address _vault = _getVaultInScope();

    // effects
    // safe to use unchecked since overflow amount would revert on borrow or transfer anyway
    unchecked {
      vaultDebtInfoMap[_vault][_token].debt += _amount.safeCastTo216();
    }

    // interactions
    moneyMarket.nonCollatBorrow(_token, _amount);

    ERC20(_token).safeTransfer(_vault, _amount);

    emit LogBorrowOnBehalfOf(_vault, msg.sender, _token, _amount);
  }

  function repayOnBehalfOf(address _token, uint256 _amount) external onlyExecutor {
    // checks
    address _vault = _getVaultInScope();

    ERC20(_token).safeTransferFrom(_vault, address(this), _amount);

    // will revert underflow if repay more than debt
    vaultDebtInfoMap[_vault][_token].debt -= _amount.safeCastTo216();

    moneyMarket.nonCollatRepay(address(this), _token, _amount);

    emit LogRepayOnBehalfOf(_vault, msg.sender, _token, _amount);
  }
}
