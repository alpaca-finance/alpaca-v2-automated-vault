// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";
import { IPancakeV3Router } from "src/interfaces/pancake-v3/IPancakeV3Router.sol";
import { IWNative } from "lib/alpaca-v2-money-market/solidity/contracts/interfaces/IWNative.sol";
import { IWNativeRelayer } from "lib/alpaca-v2-money-market/solidity/contracts/interfaces/IWNativeRelayer.sol";
import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Gateway is Ownable {
  using SafeTransferLib for ERC20;

  error Gateway_InvalidAmount();
  error Gateway_InvalidTokenOut();
  error Gateway_NativeIsNotExist();
  error Gateway_TooLittleReceived();

  AutomatedVaultManager public vaultManager;
  IPancakeV3Router public router;
  address public wNativeToken = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
  address public nativeRelayer = 0xE1D2CA01bc88F325fF7266DD2165944f3CAf0D3D;

  constructor(address _vaultManager, address _router) {
    vaultManager = AutomatedVaultManager(_vaultManager);
    router = IPancakeV3Router(_router);
  }

  function deposit(address _vaultToken, address _token, uint256 _amount, uint256 _minReceived) external {
    // pull token
    ERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

    // approve gateway to vault manager
    ERC20(_token).safeApprove(address(vaultManager), _amount);

    // build deposit params
    AutomatedVaultManager.TokenAmount[] memory _depositParams = _getDepositParams(_token, _amount);
    vaultManager.deposit(msg.sender, _vaultToken, _depositParams, _minReceived);
  }

  function depositETH(address _vaultToken, uint256 _minReceived) external payable {
    if (msg.value == 0) {
      revert Gateway_InvalidAmount();
    }
    // convert native to wrap
    IWNative(wNativeToken).deposit{ value: msg.value }();

    // approve gateway to vault manager
    ERC20(wNativeToken).safeApprove(address(vaultManager), msg.value);

    // build deposit params
    AutomatedVaultManager.TokenAmount[] memory _depositParams = _getDepositParams(wNativeToken, msg.value);
    // deposit (check slippage inside here)
    vaultManager.deposit(msg.sender, _vaultToken, _depositParams, _minReceived);
  }

  function withdrawSingleAsset(address _vaultToken, uint256 _shareToWithdraw, uint256 _minAmountOut, address _tokenOut)
    external
    returns (uint256 _amountOut)
  {
    // pull token
    ERC20(_vaultToken).safeTransferFrom(msg.sender, address(this), _shareToWithdraw);

    // withdraw
    AutomatedVaultManager.TokenAmount[] memory _minAmountOuts;
    AutomatedVaultManager.TokenAmount[] memory _result =
      vaultManager.withdraw(_vaultToken, _shareToWithdraw, _minAmountOuts);

    (address _worker,,,,,,,,) = vaultManager.vaultInfos(_vaultToken);
    address _token0 = address(PancakeV3Worker(_worker).token0());
    address _token1 = address(PancakeV3Worker(_worker).token1());

    address _tokenIn;
    uint256 _amountIn;
    uint256 _resultOut;

    // prepare token in, token out. revert if desired token out is not in token0, token1
    if (_tokenOut == _token0) {
      _tokenIn = _token1;
      _amountIn = _result[1].amount;
      _resultOut = _result[0].amount;
    } else if (_tokenOut == _token1) {
      _tokenIn = _token0;
      _amountIn = _result[0].amount;
      _resultOut = _result[1].amount;
    } else {
      revert Gateway_InvalidTokenOut();
    }

    uint256 _swapOut = 0;
    // skip if token in is 0
    if (_amountIn > 0) {
      ERC20(_tokenIn).safeApprove(address(router), _amountIn);

      _swapOut = router.exactInputSingle(
        IPancakeV3Router.ExactInputSingleParams({
          tokenIn: _tokenIn,
          tokenOut: _tokenOut,
          fee: PancakeV3Worker(_worker).poolFee(),
          recipient: address(this),
          amountIn: _amountIn,
          amountOutMinimum: 0,
          sqrtPriceLimitX96: 0
        })
      );
    }

    _amountOut = _resultOut + _swapOut;
    if (_amountOut < _minAmountOut) {
      revert Gateway_TooLittleReceived();
    }

    ERC20(_tokenOut).safeTransfer(msg.sender, _amountOut);
  }

  function withdrawETH(address _vaultToken, uint256 _shareToWithdraw, uint256 _minAmountOut)
    external
    returns (uint256 _amountOut)
  {
    // pull token
    ERC20(_vaultToken).safeTransferFrom(msg.sender, address(this), _shareToWithdraw);

    // withdraw
    AutomatedVaultManager.TokenAmount[] memory _minAmountOuts;
    AutomatedVaultManager.TokenAmount[] memory _result =
      vaultManager.withdraw(_vaultToken, _shareToWithdraw, _minAmountOuts);

    (address _worker,,,,,,,,) = vaultManager.vaultInfos(_vaultToken);
    address _token0 = address(PancakeV3Worker(_worker).token0());
    address _token1 = address(PancakeV3Worker(_worker).token1());

    address _tokenIn;
    uint256 _amountIn;
    uint256 _resultOut;

    // prepare token in, token out. revert if desired token out is not in token0, token1
    if (wNativeToken == _token0) {
      _tokenIn = _token1;
      _amountIn = _result[1].amount;
      _resultOut = _result[0].amount;
    } else if (wNativeToken == _token1) {
      _tokenIn = _token0;
      _amountIn = _result[0].amount;
      _resultOut = _result[1].amount;
    } else {
      revert Gateway_NativeIsNotExist();
    }

    uint256 _swapOut = 0;
    // send wrap to this contract
    if (_amountIn > 0) {
      _swapOut = router.exactInputSingle(
        IPancakeV3Router.ExactInputSingleParams({
          tokenIn: _tokenIn,
          tokenOut: wNativeToken,
          fee: PancakeV3Worker(_worker).poolFee(),
          recipient: address(this),
          amountIn: _amountIn,
          amountOutMinimum: 0,
          sqrtPriceLimitX96: 0
        })
      );
    }
    _amountOut = _resultOut + _swapOut;

    if (_amountOut < _minAmountOut) {
      revert Gateway_TooLittleReceived();
    }
    // unwrap and send to msg.sender
    _safeUnwrap(msg.sender, _amountOut);
  }

  function _getDepositParams(address _token, uint256 _amount)
    internal
    pure
    returns (AutomatedVaultManager.TokenAmount[] memory)
  {
    AutomatedVaultManager.TokenAmount[] memory _depositParams = new AutomatedVaultManager.TokenAmount[](1);
    _depositParams[0] = AutomatedVaultManager.TokenAmount({ token: _token, amount: _amount });
    return _depositParams;
  }

  function _safeUnwrap(address _to, uint256 _amount) internal {
    ERC20(wNativeToken).safeTransfer(nativeRelayer, _amount);
    IWNativeRelayer(nativeRelayer).withdraw(_amount);
    SafeTransferLib.safeTransferETH(_to, _amount);
  }

  /// @notice Withdraw ERC20 from this contract
  /// @param _to An destination address
  /// @param _tokens A list of withdraw tokens
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
    ERC20(_token).safeTransfer(_to, ERC20(_token).balanceOf(address(this)));
  }

  receive() external payable { }
}
