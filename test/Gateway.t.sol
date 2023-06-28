// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./fixtures/E2EFixture.f.sol";
import { AutomatedVaultManager, MAX_BPS } from "src/AutomatedVaultManager.sol";
import { IWNativeRelayer } from "lib/alpaca-v2-money-market/solidity/contracts/interfaces/IWNativeRelayer.sol";

import { Gateway } from "src/Gateway.sol";

contract GatewayTest is E2EFixture {
  Gateway internal gateway;

  constructor() E2EFixture() {
    gateway = new Gateway(address(vaultManager), address(pancakeV3Router));
  }

  function _depositGateway(address _depositor, IERC20 _token, uint256 _amount) internal {
    deal(address(_token), _depositor, _amount);

    uint256 _depositorBalanceBefore = _token.balanceOf(_depositor);

    vm.startPrank(_depositor);
    _token.approve(address(gateway), _amount);
    gateway.deposit(address(vaultToken), address(_token), _amount, 0);
    vm.stopPrank();

    uint256 _depositorBalanceAfter = _token.balanceOf(_depositor);

    // user balance must be deducted
    assertEq(_depositorBalanceBefore - _depositorBalanceAfter, _amount);
    // gateway must have nothing
    assertEq(_token.balanceOf(address(gateway)), 0);
  }

  function _depositNativeGateway(address _depositor, uint256 _amount) internal {
    deal(_depositor, _amount);

    uint256 _depositorBalanceBefore = _depositor.balance;

    vm.startPrank(_depositor);
    gateway.depositETH{ value: _amount }(address(vaultToken), 0);
    vm.stopPrank();

    uint256 _depositorBalanceAfter = _depositor.balance;

    // user balance must be deducted
    assertEq(_depositorBalanceBefore - _depositorBalanceAfter, _amount);
    // gateway must have nothing
    assertEq(address(gateway).balance, 0);
  }

  function _withdrawGateway(address _caller, uint256 _share, address _tokenOut) internal {
    uint256 _balanceTokenOutBefore = IERC20(_tokenOut).balanceOf(_caller);

    vm.startPrank(_caller);
    vaultToken.approve(address(gateway), _share);
    uint256 _amountOut = gateway.withdrawSingleAsset(address(vaultToken), _share, 0, _tokenOut);
    vm.stopPrank();

    uint256 _balanceTokenOutAfter = IERC20(_tokenOut).balanceOf(_caller);

    // assert user token balance
    assertEq(_balanceTokenOutAfter - _balanceTokenOutBefore, _amountOut);

    // gateway must have nothing
    assertEq(wbnb.balanceOf(address(gateway)), 0);
    assertEq(usdt.balanceOf(address(gateway)), 0);
  }

  function _withdrawNativeGateway(address _caller, uint256 _share) internal {
    uint256 _balanceNativeBefore = address(_caller).balance;

    vm.startPrank(_caller);
    vaultToken.approve(address(gateway), _share);
    uint256 _amountOut = gateway.withdrawETH(address(vaultToken), _share, 0);
    vm.stopPrank();

    uint256 _balanceNativeAfter = address(_caller).balance;
    // assert user native balance
    assertEq(_balanceNativeAfter - _balanceNativeBefore, _amountOut);

    // gateway must have nothing
    assertEq(wbnb.balanceOf(address(gateway)), 0);
    assertEq(usdt.balanceOf(address(gateway)), 0);
    assertEq(address(gateway).balance, 0);
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
    // 1. deposit wbnb = 1 ether. expect withdraw and token out is "wbnb" should work
    _depositGateway(address(this), wbnb, 1 ether);
    uint256 _share = vaultToken.balanceOf(address(this));
    _withdrawGateway(address(this), _share, address(wbnb));

    // 2. deposit usdt = 1 ether. expect withdraw and token out is "usdt" should work
    _depositGateway(address(this), usdt, 1 ether);
    _share = vaultToken.balanceOf(address(this));
    _withdrawGateway(address(this), _share, address(usdt));

    // 3. deposit usdt = 1 ether. expect withdraw and token out is "wbnb" should work
    _depositGateway(address(this), usdt, 1 ether);
    _share = vaultToken.balanceOf(address(this));
    _withdrawGateway(address(this), _share, address(wbnb));

    // 4. deposit wbnb = 1 ether. expect withdraw and token out is "usdt" should work
    _depositGateway(address(this), wbnb, 1 ether);
    _share = vaultToken.balanceOf(address(this));
    _withdrawGateway(address(this), _share, address(usdt));
  }

  function testCorrectness_WithdrawNative_withGateway_ShouldWork() external {
    // wNativeRelayer allows to withdraw from wbnb to bnb
    address owner = 0xC44f82b07Ab3E691F826951a6E335E1bC1bB0B51;
    address relayer = 0xE1D2CA01bc88F325fF7266DD2165944f3CAf0D3D;
    address[] memory _callers = new address[](1);
    _callers[0] = address(gateway);
    vm.prank(owner);
    IWNativeRelayer(relayer).setCallerOk(_callers, true);

    // 1. deposit wbnb = 1 ether, expect withdraw and bnb balance should equal 1 ether
    uint256 _amount = 1 ether;
    _depositNativeGateway(address(this), _amount);
    uint256 _share = vaultToken.balanceOf(address(this));
    _withdrawNativeGateway(address(this), _share);

    // bnb balance should equal 1 ether
    assertEq(address(this).balance, _amount);
  }

  function testRevert_Deposit_InvalidInput() external {
    // deposit token = address(0)
    vm.expectRevert(abi.encodeWithSelector(Gateway.Gateway_InvalidInput.selector));
    gateway.deposit(address(vaultToken), address(0), 1 ether, 0);

    // erc20 token amount = 0
    vm.expectRevert(abi.encodeWithSelector(Gateway.Gateway_InvalidInput.selector));
    gateway.deposit(address(vaultToken), address(wbnb), 0, 0);

    // native
    vm.expectRevert(abi.encodeWithSelector(Gateway.Gateway_InvalidInput.selector));
    gateway.depositETH{ value: 0 }(address(vaultToken), 0);
  }

  function testRevert_WhenWithdraw_WithInvalidToken() external {
    // withdraw revert when token out is not in token0, token1
    _depositGateway(address(this), wbnb, 1 ether);
    _depositGateway(address(this), usdt, 1 ether);
    uint256 _share = vaultToken.balanceOf(address(this));
    vaultToken.approve(address(gateway), _share);
    vm.expectRevert(abi.encodeWithSelector(Gateway.Gateway_InvalidTokenOut.selector));
    gateway.withdrawSingleAsset(address(vaultToken), _share, 0, address(cake));

    // withdraw native on vault that have no wbnb pool (TODO)
  }

  function testRevert_WhenWithdrawAmountOut_IsLessThan_MinReceive() external {
    _depositGateway(address(this), wbnb, 1 ether);
    uint256 _share = vaultToken.balanceOf(address(this));
    vaultToken.approve(address(gateway), _share);
    vm.expectRevert(abi.encodeWithSelector(Gateway.Gateway_TooLittleReceived.selector));
    gateway.withdrawSingleAsset(address(vaultToken), _share, 350 ether, address(usdt));
  }

  receive() external payable { }
}
