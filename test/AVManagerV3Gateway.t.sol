// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./fixtures/E2EFixture.f.sol";
import { AutomatedVaultManager, MAX_BPS } from "src/AutomatedVaultManager.sol";
import { AVManagerV3Gateway, ERC20 } from "src/AVManagerV3Gateway.sol";

contract AVManagerV3GatewayTest is E2EFixture {
  AVManagerV3Gateway internal avManagerV3Gateway;

  constructor() E2EFixture() {
    avManagerV3Gateway = new AVManagerV3Gateway(address(vaultManager), address(pancakeV3Router));
  }

  function _depositGateway(address _depositor, IERC20 _token, uint256 _amount) internal {
    deal(address(_token), _depositor, _amount);

    uint256 _depositorBalanceBefore = _token.balanceOf(_depositor);
    uint256 _userVaultShareBefore = vaultToken.balanceOf(_depositor);
    uint256 _totalVaultTokenBefore = vaultToken.totalSupply();

    vm.startPrank(_depositor);
    _token.approve(address(avManagerV3Gateway), _amount);
    avManagerV3Gateway.deposit(address(vaultToken), address(_token), _amount, 0);
    vm.stopPrank();

    uint256 _depositorBalanceAfter = _token.balanceOf(_depositor);
    uint256 _userVaultShareAfter = vaultToken.balanceOf(_depositor);
    uint256 _totalVaultTokenAfter = vaultToken.totalSupply();

    // user balance must be deducted
    assertEq(_depositorBalanceBefore - _depositorBalanceAfter, _amount);

    // user's increasing share ~= vaultToken's increasing share (assume management fee = 0)
    assertEq(_userVaultShareAfter - _userVaultShareBefore, _totalVaultTokenAfter - _totalVaultTokenBefore);

    // avManagerV3Gateway must have nothing
    assertEq(_token.balanceOf(address(avManagerV3Gateway)), 0);
  }

  function _depositNativeGateway(address _depositor, uint256 _amount) internal {
    deal(_depositor, _amount);

    uint256 _depositorBalanceBefore = _depositor.balance;
    uint256 _userVaultShareBefore = vaultToken.balanceOf(_depositor);
    uint256 _totalVaultTokenBefore = vaultToken.totalSupply();

    vm.startPrank(_depositor);
    avManagerV3Gateway.depositETH{ value: _amount }(address(vaultToken), 0);
    vm.stopPrank();

    uint256 _depositorBalanceAfter = _depositor.balance;
    uint256 _userVaultShareAfter = vaultToken.balanceOf(_depositor);
    uint256 _totalVaultTokenAfter = vaultToken.totalSupply();

    // user balance must be deducted
    assertEq(_depositorBalanceBefore - _depositorBalanceAfter, _amount);

    // user's increasing share ~= vaultToken's increasing share (assume management fee = 0)
    assertEq(_userVaultShareAfter - _userVaultShareBefore, _totalVaultTokenAfter - _totalVaultTokenBefore);

    // avManagerV3Gateway must have nothing
    assertEq(address(avManagerV3Gateway).balance, 0);
  }

  function _withdrawGateway(address _caller, uint256 _share, bool _zeroForOne) internal returns (uint256 _amountOut) {
    (address _worker,,,,,,,,) = vaultManager.vaultInfos(address(vaultToken));
    ERC20 _tokenOut = _zeroForOne ? PancakeV3Worker(_worker).token1() : PancakeV3Worker(_worker).token0();

    uint256 _userVaultShareBefore = vaultToken.balanceOf(_caller);
    uint256 _totalVaultTokenBefore = vaultToken.totalSupply();
    uint256 _userTokOutBalanceBefore = _tokenOut.balanceOf(_caller);

    vm.startPrank(_caller);
    vaultToken.approve(address(avManagerV3Gateway), _share);
    _amountOut = avManagerV3Gateway.withdrawConvertAll(address(vaultToken), _share, _zeroForOne, 0);
    vm.stopPrank();

    uint256 _userVaultShareAfter = vaultToken.balanceOf(_caller);
    uint256 _totalVaultTokenAfter = vaultToken.totalSupply();
    uint256 _userTokOutBalanceAfter = _tokenOut.balanceOf(_caller);

    // user token out balance should increase
    assertEq(_userTokOutBalanceAfter - _userTokOutBalanceBefore, _amountOut);

    // user's decreasing share ~= vaultToken's decreasing share (assume management fee = 0)
    assertEq(_userVaultShareBefore - _userVaultShareAfter, _totalVaultTokenBefore - _totalVaultTokenAfter);

    // avManagerV3Gateway must have nothing
    assertEq(wbnb.balanceOf(address(avManagerV3Gateway)), 0);
    assertEq(usdt.balanceOf(address(avManagerV3Gateway)), 0);
  }

  function _withdrawNativeGateway(address _caller, uint256 _share) internal {
    uint256 _balanceNativeBefore = address(_caller).balance;
    uint256 _userVaultShareBefore = vaultToken.balanceOf(_caller);
    uint256 _totalVaultTokenBefore = vaultToken.totalSupply();

    vm.startPrank(_caller);
    vaultToken.approve(address(avManagerV3Gateway), _share);
    uint256 _amountOut = avManagerV3Gateway.withdrawETH(address(vaultToken), _share, 0);
    vm.stopPrank();

    uint256 _balanceNativeAfter = address(_caller).balance;
    uint256 _userVaultShareAfter = vaultToken.balanceOf(_caller);
    uint256 _totalVaultTokenAfter = vaultToken.totalSupply();

    // user's decreasing share ~= vaultToken's decreasing share (assume management fee = 0)
    assertEq(_userVaultShareBefore - _userVaultShareAfter, _totalVaultTokenBefore - _totalVaultTokenAfter);

    // assert user native balance
    assertEq(_balanceNativeAfter - _balanceNativeBefore, _amountOut);

    // avManagerV3Gateway must have nothing
    assertEq(wbnb.balanceOf(address(avManagerV3Gateway)), 0);
    assertEq(usdt.balanceOf(address(avManagerV3Gateway)), 0);
    assertEq(address(avManagerV3Gateway).balance, 0);
  }

  function testCorrectness_DepositToken_withGateway_ShouldWork() external {
    uint256 _amount = 1 ether;

    // 1. deposit wbnb = 1 ether, worker should have 1 wbnb
    _depositGateway(address(this), wbnb, _amount);

    assertEq(wbnb.balanceOf(address(workerUSDTWBNB)), _amount);
    assertEq(usdt.balanceOf(address(workerUSDTWBNB)), 0);

    // 2. deposit usdt = 1 ether, worker should have 1 usdt
    _depositGateway(address(this), usdt, _amount);
    assertEq(wbnb.balanceOf(address(workerUSDTWBNB)), _amount);
    assertEq(usdt.balanceOf(address(workerUSDTWBNB)), _amount);
  }

  function testCorrectness_DepositNative_withGateway_ShouldWork() external {
    // 1. deposit bnb = 1 ether, worker should have 1 wbnb
    uint256 _amount = 1 ether;
    _depositNativeGateway(address(this), _amount);

    assertEq(wbnb.balanceOf(address(workerUSDTWBNB)), _amount);
    assertEq(usdt.balanceOf(address(workerUSDTWBNB)), 0);
  }

  function testCorrectness_WithdrawToken_withGateway_ShouldWork() external {
    // Note: In this vault
    // true: withdraw as WBNB
    // false: withdraw as USDT

    // 1. deposit wbnb = 1 ether. expect withdraw and token out is "wbnb" should work
    _depositGateway(address(this), wbnb, 1 ether);
    uint256 _share = vaultToken.balanceOf(address(this));
    _withdrawGateway(address(this), _share, true);

    // 2. deposit usdt = 1 ether. expect withdraw and token out is "usdt" should work
    _depositGateway(address(this), usdt, 1 ether);
    _share = vaultToken.balanceOf(address(this));
    _withdrawGateway(address(this), _share, false);

    // 3. deposit usdt = 1 ether. expect withdraw and token out is "wbnb" should work
    _depositGateway(address(this), usdt, 1 ether);
    _share = vaultToken.balanceOf(address(this));
    _withdrawGateway(address(this), _share, true);

    // 4. deposit wbnb = 1 ether. expect withdraw and token out is "usdt" should work
    _depositGateway(address(this), wbnb, 1 ether);
    _share = vaultToken.balanceOf(address(this));
    _withdrawGateway(address(this), _share, false);
  }

  function testCorrectness_WithdrawNative_withGateway_ShouldWork() external {
    // 1. deposit wbnb = 1 ether, expect withdraw and bnb balance should equal 1 ether
    uint256 _amount = 1 ether;
    _depositNativeGateway(address(this), _amount);
    uint256 _share = vaultToken.balanceOf(address(this));
    _withdrawNativeGateway(address(this), _share);
  }

  function testRevert_Deposit_InvalidInput() external {
    // erc20 token amount = 0
    vm.expectRevert(abi.encodeWithSelector(AVManagerV3Gateway.AVManagerV3Gateway_InvalidInput.selector));
    avManagerV3Gateway.deposit(address(vaultToken), address(wbnb), 0, 0);

    // native
    vm.expectRevert(abi.encodeWithSelector(AVManagerV3Gateway.AVManagerV3Gateway_InvalidInput.selector));
    avManagerV3Gateway.depositETH{ value: 0 }(address(vaultToken), 0);
  }

  function testRevert_WhenWithdraw_WithInvalidToken() external {
    // withdraw native on vault that have no wbnb pool (TODO)
  }

  function testRevert_WhenWithdrawAmountOut_IsLessThan_MinReceive() external {
    _depositGateway(address(this), wbnb, 1 ether);
    uint256 _share = vaultToken.balanceOf(address(this));
    vaultToken.approve(address(avManagerV3Gateway), _share);

    // withdrawToken
    vm.expectRevert(abi.encodeWithSelector(AVManagerV3Gateway.AVManagerV3Gateway_TooLittleReceived.selector));
    avManagerV3Gateway.withdrawConvertAll(address(vaultToken), _share, true, 350 ether);

    // withdrawNative
    vm.expectRevert(abi.encodeWithSelector(AVManagerV3Gateway.AVManagerV3Gateway_TooLittleReceived.selector));
    avManagerV3Gateway.withdrawETH(address(vaultToken), _share, 2 ether);
  }

  receive() external payable { }
}
