// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";
import { SafeCastLib } from "@solmate/utils/SafeCastLib.sol";

// interfaces
import { IMoneyMarket } from "@alpaca-mm/money-market/interfaces/IMoneyMarket.sol";

contract DebtManager {
  using SafeCastLib for uint256;
  using SafeTransferLib for ERC20;

  error DebtManager_Unauthorized();

  IMoneyMarket public immutable moneyMarket;

  struct VaultDebtInfo {
    // packed slot
    uint216 debt; // TODO: maybe debt shares if AV accrue interest
    uint40 lastAccrualTime;
  }

  // vault address => token => debt shares
  mapping(address => mapping(address => VaultDebtInfo)) public vaultDebtInfoMap;
  mapping(address => bool) public executorsOk;

  event LogSetExecutorsOk(address[] _executors, bool _isOk);

  modifier onlyExecutor() {
    if (!executorsOk[msg.sender]) revert DebtManager_Unauthorized();
    _;
  }

  constructor(address _moneyMarket) {
    moneyMarket = IMoneyMarket(_moneyMarket);
  }

  // TODO: onlyOwner
  function setExecutorsOk(address[] calldata _executors, bool _isOk) external {
    uint256 _len = _executors.length;
    for (uint256 _i; _i < _len;) {
      executorsOk[_executors[_i]] = _isOk;
      unchecked {
        ++_i;
      }
    }
    emit LogSetExecutorsOk(_executors, _isOk);
  }

  function borrowOnBehalfOf(address _borrower, address _token, uint256 _amount) external onlyExecutor {
    // effects
    // safe to use unchecked since overflow amount would revert on borrow or transfer anyway
    unchecked {
      vaultDebtInfoMap[_borrower][_token].debt += _amount.safeCastTo216();
    }

    // interactions
    moneyMarket.nonCollatBorrow(_token, _amount);

    ERC20(_token).safeTransfer(_borrower, _amount);
  }

  function repayOnBehalfOf(address _borrower, address _token, uint256 _amount) external onlyExecutor {
    ERC20(_token).safeTransferFrom(_borrower, address(this), _amount);

    // will revert underflow if repay more than debt
    vaultDebtInfoMap[_borrower][_token].debt -= _amount.safeCastTo216();

    moneyMarket.nonCollatRepay(address(this), _token, _amount);
  }
}
