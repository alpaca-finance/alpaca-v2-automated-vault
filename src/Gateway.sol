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

    // build deposit params
    AutomatedVaultManager.TokenAmount[] memory _depositParams = _getDepositParams(wNativeToken, msg.value);
    // deposit (check slippage inside here)
    vaultManager.deposit(msg.sender, _vaultToken, _depositParams, _minReceived);
  }

  function withdrawSingleAsset(address _vaultToken, uint256 _shareToWithdraw, uint256 _minAmountOut, address _tokenOut)
    external
    returns (uint256 _amountOut)
  {
    // Validate first
    (address _worker,,,,,,,,) = vaultManager.vaultInfos(_vaultToken);
    address _token0 = address(PancakeV3Worker(_worker).token0());
    address _token1 = address(PancakeV3Worker(_worker).token1());

    // Revert if token out is not existing
    if (_tokenOut != _token0 && _tokenOut != _token1) {
      revert Gateway_InvalidTokenOut();
    }

    // pull token
    ERC20(_vaultToken).safeTransferFrom(msg.sender, address(this), _shareToWithdraw);

    // withdraw
    AutomatedVaultManager.TokenAmount[] memory _minAmountOuts;
    AutomatedVaultManager.TokenAmount[] memory _result =
      vaultManager.withdraw(_vaultToken, _shareToWithdraw, _minAmountOuts);

    // if token out is token0, then token in is token1
    address _tokenIn = _tokenOut == _token0 ? _token1 : _token0;
    // if token in is token0, then amount in is amount0
    uint256 _amountIn = _tokenIn == _token0 ? _result[0].amount : _result[1].amount;

    // send token directly to user
    _amountOut = router.exactInputSingle(
      IPancakeV3Router.ExactInputSingleParams({
        tokenIn: _tokenIn,
        tokenOut: _tokenOut,
        fee: PancakeV3Worker(_worker).poolFee(),
        recipient: msg.sender,
        amountIn: _amountIn,
        amountOutMinimum: _minAmountOut,
        sqrtPriceLimitX96: 0
      })
    );
  }

  function withdrawETH(address _vaultToken, uint256 _shareToWithdraw, uint256 _minAmountOut)
    external
    returns (uint256 _amountOut)
  {
    // Validate first
    (address _worker,,,,,,,,) = vaultManager.vaultInfos(_vaultToken);
    address _token0 = address(PancakeV3Worker(_worker).token0());
    address _token1 = address(PancakeV3Worker(_worker).token1());

    // Revert if token out is not existing
    if (_token0 != wNativeToken && _token1 != wNativeToken) {
      revert Gateway_NativeIsNotExist();
    }

    // pull token
    ERC20(_vaultToken).safeTransferFrom(msg.sender, address(this), _shareToWithdraw);

    // withdraw
    AutomatedVaultManager.TokenAmount[] memory _minAmountOuts;
    AutomatedVaultManager.TokenAmount[] memory _result =
      vaultManager.withdraw(_vaultToken, _shareToWithdraw, _minAmountOuts);

    // if token0 is wNativeToken, then token in is token1
    address _tokenIn = _token0 == wNativeToken ? _token1 : _token0;
    // if token in is token0, then amount in is amount0
    uint256 _amountIn = _tokenIn == _token0 ? _result[0].amount : _result[1].amount;

    // send wrap to this contract
    _amountOut = router.exactInputSingle(
      IPancakeV3Router.ExactInputSingleParams({
        tokenIn: _tokenIn,
        tokenOut: wNativeToken,
        fee: PancakeV3Worker(_worker).poolFee(),
        recipient: address(this),
        amountIn: _amountIn,
        amountOutMinimum: _minAmountOut,
        sqrtPriceLimitX96: 0
      })
    );

    // unwrap and send to msg.sender
    _safeUnwrap(msg.sender, _amountOut);
  }

  function _safeUnwrap(address _to, uint256 _amount) internal {
    ERC20(wNativeToken).safeTransfer(nativeRelayer, _amount);
    IWNativeRelayer(nativeRelayer).withdraw(_amount);
    SafeTransferLib.safeTransferETH(_to, _amount);
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
    ERC20(_token).safeTransfer(_to, ERC20(_token).balanceOf(address(this)));
  }

  receive() external payable { }
}
