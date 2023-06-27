// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { IERC20 } from "src/interfaces/IERC20.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";
import { ICommonV3Pool } from "src/interfaces/ICommonV3Pool.sol";
import { IWNative } from "lib/alpaca-v2-money-market/solidity/contracts/interfaces/IWNative.sol";
import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Gateway is Ownable {
  using SafeTransferLib for ERC20;

  AutomatedVaultManager public vaultManager;
  IPancakeV3Router public router;

  constructor(address _vaultManager, _router) {
    vaultManager = AutomatedVaultManager(_vaultManager);
    router = IPancakeV3Router(_router);
  }

  // function to call deposit when user given native
  // - wrap native
  // - deposit wrap to avm

  error invalid_deposit();

  function deposit(address _vaultToken, address _token, uint256 _amount, uint256 _minReceived) external {
    // pull token
    IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

    // build deposit params
    AutomatedVaultManager.TokenAmount[] memory _depositParams = _getDepositParams(_token, _amount);
    vaultManager.deposit(msg.sender, _vaultToken, _depositParams, _minReceived);
  }

  function depositETH(address _vaultToken, uint256 _minReceived) external payable {
    if (msg.value <= 0) {
      revert invalid_deposit();
    }
    // convert native to wrap
    IWNative(wNative).deposit{ value: msg.value }();

    // build deposit params
    AutomatedVaultManager.TokenAmount[] memory _depositParams = _getDepositParams(wNative, msg.value);
    // deposit (check slippage inside here)
    vaultManager.deposit(msg.sender, _vaultToken, _depositParams, _minReceived);
  }

  // TODO: specific token out
  function withdrawSingleAsset(address _vaultToken, uint256 _shareToWithdraw, uint256 _minAmountOut, bool flag)
    external
    returns (uint256 _amountOut)
  {
    // pull token
    IERC20(_vaultToken).safeTransferFrom(msg.sender, address(this), _shareToWithdraw);

    (address _worker,,,,,,,,) = vaultManager.vaultInfos(_vaultToken);

    ERC20 _token0 = PancakeV3Worker(_worker).token0;
    ERC20 _token1 = PancakeV3Worker(_worker).token1;
    uint24 _poolFee = PancakeV3Worker(_worker).poolFee;
    // withdraw
    AutomatedVaultManager.TokenAmount memory _result = vaultManager.withdraw(_vaultToken, _shareToWithdraw, 0);
    // convert token1 => token0

    if (flag) {
      _amountOut = router.exactInputSingle(
        IPancakeV3Router.ExactInputSingleParams({
          tokenIn: address(_token1),
          tokenOut: address(_token0),
          fee: _poolFee,
          recipient: msg.sender,
          amountIn: _result[1].amount,
          amountOutMinimum: _minAmountOut,
          sqrtPriceLimitX96: 0
        })
      );
    } else {
      _amountOut = router.exactInputSingle(
        IPancakeV3Router.ExactInputSingleParams({
          tokenIn: address(_token0),
          tokenOut: address(_token1),
          fee: _poolFee,
          recipient: msg.sender,
          amountIn: _result[0].amount,
          amountOutMinimum: _minAmountOut,
          sqrtPriceLimitX96: 0
        })
      );
    }
  }

  function _getDepositParams(address _token, uint256 _amount)
    internal
    returns (AutomatedVaultManager.TokenAmount[] memory)
  {
    AutomatedVaultManager.TokenAmount[] memory _depositParams = new AutomatedVaultManager.TokenAmount[](1);
    _depositParams[0] = AutomatedVaultManager.TokenAmount({ token: _token, amount: _amount });
    return _depositParams;
  }

  function withdraw(address _to, address[] calldata _tokens) external onlyOwner {
    uint256 _length = _tokens.length;
    for (uint256 _i; _i < _length;) {
      _withdraw(_to, _tokens[_i]);
      unchecked {
        ++_i;
      }
    }
  }

  function _withdraw(address _to, address _token) internal {
    IERC20(_token).safeTransfer(_to, IERC20(_token).balanceOf(address(this)));
  }

  receive() external payable { }
}
