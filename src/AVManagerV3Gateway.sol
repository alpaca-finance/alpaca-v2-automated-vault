// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";

// libraries
import { LibTickMath } from "src/libraries/LibTickMath.sol";
import { IWNative } from "lib/alpaca-v2-money-market/solidity/contracts/interfaces/IWNative.sol";
import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

// interfaces
import { ICommonV3Pool } from "src/interfaces/ICommonV3Pool.sol";
import { IPancakeV3Router } from "src/interfaces/pancake-v3/IPancakeV3Router.sol";
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";

contract AVManagerV3Gateway is Ownable {
  using SafeTransferLib for ERC20;

  error AVManagerV3Gateway_InvalidInput();
  error AVManagerV3Gateway_InvalidAddress();
  error AVManagerV3Gateway_NativeIsNotExist();
  error AVManagerV3Gateway_TooLittleReceived();
  error AVManagerV3Gateway_NotPool();

  AutomatedVaultManager public immutable vaultManager;
  IPancakeV3Router public immutable router;
  address public constant wNativeToken = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

  constructor(address _vaultManager, address _router) {
    if (_vaultManager == address(0) || _router == address(0)) {
      revert AVManagerV3Gateway_InvalidAddress();
    }
    vaultManager = AutomatedVaultManager(_vaultManager);
    router = IPancakeV3Router(_router);
  }

  function deposit(address _vaultToken, address _token, uint256 _amount, uint256 _minReceived)
    external
    returns (bytes memory _result)
  {
    if (_amount == 0) {
      revert AVManagerV3Gateway_InvalidInput();
    }

    // pull token
    ERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

    // approve AVManagerV3Gateway to vault manager
    ERC20(_token).safeApprove(address(vaultManager), _amount);

    // build deposit params
    AutomatedVaultManager.TokenAmount[] memory _depositParams = _getDepositParams(_token, _amount);
    _result = vaultManager.deposit(msg.sender, _vaultToken, _depositParams, _minReceived);
  }

  function depositETH(address _vaultToken, uint256 _minReceived) external payable returns (bytes memory _result) {
    if (msg.value == 0) {
      revert AVManagerV3Gateway_InvalidInput();
    }
    // convert native to wrap
    IWNative(wNativeToken).deposit{ value: msg.value }();

    // approve AVManagerV3Gateway to vault manager
    ERC20(wNativeToken).safeApprove(address(vaultManager), msg.value);

    // build deposit params
    AutomatedVaultManager.TokenAmount[] memory _depositParams = _getDepositParams(wNativeToken, msg.value);
    // deposit (check slippage inside here)
    _result = vaultManager.deposit(msg.sender, _vaultToken, _depositParams, _minReceived);
  }

  function withdrawMinimizeTrading(
    address _vaultToken,
    uint256 _shareToWithdraw,
    AutomatedVaultManager.TokenAmount[] memory _minAmountOut
  ) external returns (AutomatedVaultManager.TokenAmount[] memory _result) {
    _result = _withdraw(_vaultToken, _shareToWithdraw, _minAmountOut);
  }

  function withdrawConvertAll(address _vaultToken, uint256 _shareToWithdraw, bool _zeroForOne, uint256 _minAmountOut)
    external
    returns (uint256 _amountOut)
  {
    AutomatedVaultManager.TokenAmount[] memory _minAmountOuts;
    _withdraw(_vaultToken, _shareToWithdraw, _minAmountOuts);

    (address _worker,,,,,,,,) = vaultManager.vaultInfos(_vaultToken);
    ERC20 _token0 = PancakeV3Worker(_worker).token0();
    ERC20 _token1 = PancakeV3Worker(_worker).token1();
    ICommonV3Pool _pool = PancakeV3Worker(_worker).pool();

    ERC20 _tokenOut;
    uint256 _amountIn;
    if (_zeroForOne) {
      _tokenOut = _token1;
      _amountIn = _token0.balanceOf(address(this));
    } else {
      _tokenOut = _token0;
      _amountIn = _token1.balanceOf(address(this));
    }

    // skip swap when amount = 0
    if (_amountIn > 0) {
      _pool.swap(
        address(this),
        _zeroForOne,
        int256(_amountIn),
        _zeroForOne ? LibTickMath.MIN_SQRT_RATIO + 1 : LibTickMath.MAX_SQRT_RATIO - 1,
        abi.encode(address(_token0), address(_token1), _pool.fee())
      );
    }

    _amountOut = _tokenOut.balanceOf(address(this));
    if (_amountOut < _minAmountOut) {
      revert AVManagerV3Gateway_TooLittleReceived();
    }

    _tokenOut.safeTransfer(msg.sender, _amountOut);
  }

  function withdrawETH(address _vaultToken, uint256 _shareToWithdraw, uint256 _minAmountOut)
    external
    returns (uint256 _amountOut)
  {
    AutomatedVaultManager.TokenAmount[] memory _minAmountOuts;
    _withdraw(_vaultToken, _shareToWithdraw, _minAmountOuts);

    (address _worker,,,,,,,,) = vaultManager.vaultInfos(_vaultToken);
    ICommonV3Pool _pool = PancakeV3Worker(_worker).pool();
    ERC20 _token0 = PancakeV3Worker(_worker).token0();
    ERC20 _token1 = PancakeV3Worker(_worker).token1();

    bool _zeroForOne;
    uint256 _amountIn;

    if (address(_token0) == wNativeToken) {
      _zeroForOne = false;
      _amountIn = _token1.balanceOf(address(this));
    } else if (address(_token1) == wNativeToken) {
      _zeroForOne = true;
      _amountIn = _token0.balanceOf(address(this));
    } else {
      revert AVManagerV3Gateway_NativeIsNotExist();
    }

    // skip swap when amount = 0
    if (_amountIn > 0) {
      _pool.swap(
        address(this),
        _zeroForOne,
        int256(_amountIn),
        _zeroForOne ? LibTickMath.MIN_SQRT_RATIO + 1 : LibTickMath.MAX_SQRT_RATIO - 1,
        abi.encode(address(_token0), address(_token1), _pool.fee())
      );
    }

    _amountOut = ERC20(wNativeToken).balanceOf(address(this));
    if (_amountOut < _minAmountOut) {
      revert AVManagerV3Gateway_TooLittleReceived();
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

  function pancakeV3SwapCallback(int256 _amount0Delta, int256 _amount1Delta, bytes calldata _data) external {
    (address _token0, address _token1, uint24 _fee) = abi.decode(_data, (address, address, uint24));
    address _pool = address(
      uint160(
        uint256(
          keccak256(
            abi.encodePacked(
              hex"ff",
              0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9,
              keccak256(abi.encode(_token0, _token1, _fee)),
              bytes32(0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2)
            )
          )
        )
      )
    );
    if (msg.sender == _pool) {
      if (_amount0Delta > 0) {
        ERC20(_token0).safeTransfer(msg.sender, uint256(_amount0Delta));
      } else {
        ERC20(_token1).safeTransfer(msg.sender, uint256(_amount1Delta));
      }
    } else {
      revert AVManagerV3Gateway_NotPool();
    }
  }

  function _safeUnwrap(address _to, uint256 _amount) internal {
    IWNative(wNativeToken).withdraw(_amount);
    SafeTransferLib.safeTransferETH(_to, _amount);
  }

  function _withdraw(
    address _vaultToken,
    uint256 _shareToWithdraw,
    AutomatedVaultManager.TokenAmount[] calldata _minAmountOuts
  ) internal returns (AutomatedVaultManager.TokenAmount[] memory _result) {
    // pull token
    ERC20(_vaultToken).safeTransferFrom(msg.sender, address(this), _shareToWithdraw);
    // withdraw
    _result = vaultManager.withdraw(_vaultToken, _shareToWithdraw, _minAmountOuts);
  }

  /// @notice Withdraw ERC20 from this contract
  /// @param _to An destination address
  /// @param _tokens A list of withdraw tokens
  function ownerWithdraw(address _to, address[] calldata _tokens) external onlyOwner {
    uint256 _length = _tokens.length;
    for (uint256 _i; _i < _length;) {
      _ownerWithdraw(_to, _tokens[_i]);
      unchecked {
        ++_i;
      }
    }
  }

  function _ownerWithdraw(address _to, address _token) internal {
    ERC20(_token).safeTransfer(_to, ERC20(_token).balanceOf(address(this)));
  }

  receive() external payable { }
}
