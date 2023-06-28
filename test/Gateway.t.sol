// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./fixtures/E2EFixture.f.sol";
import { AutomatedVaultManager, MAX_BPS } from "src/AutomatedVaultManager.sol";
import { IWNativeRelayer } from "lib/alpaca-v2-money-market/solidity/contracts/interfaces/IWNativeRelayer.sol";

import { Gateway } from "src/Gateway.sol";

contract GatewayTest is E2EFixture {
  Gateway internal gateway;

  constructor() E2EFixture() { }

  function setUp() public {
    gateway = new Gateway(address(vaultManager), address(pancakeV3Router));
  }

  function _depositGateway(address _depositor, IERC20 _token, uint256 _amount) internal {
    deal(address(_token), _depositor, _amount);

    vm.startPrank(_depositor);
    _token.approve(address(gateway), _amount);
    gateway.deposit(address(vaultToken), address(_token), _amount, 0);
    vm.stopPrank();

    // worker deposit token balance should equal deposit amount
    assertEq(_token.balanceOf(address(workerUSDTWBNB)), _amount);
    // gateway must have nothing
    assertEq(_token.balanceOf(address(gateway)), 0);
  }

  function _depositNativeGateway(address _depositor, uint256 _amount) internal {
    deal(_depositor, _amount);

    vm.startPrank(_depositor);
    gateway.depositETH{ value: _amount }(address(vaultToken), 0);
    vm.stopPrank();

    // worker wbnb token balance should equal deposit amount
    assertEq(wbnb.balanceOf(address(workerUSDTWBNB)), _amount);
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
    assertEq(address(gateway).balance, 0);
  }

  function testCorrectness_DepositToken_withGateway_ShouldWork() external {
    // 1. deposit wbnb = 1 ether, worker should have 1 wbnb
    _depositGateway(address(this), wbnb, 1 ether);
    // 2. deposit usdt = 1 ether, worker should have 1 usdt
    _depositGateway(address(this), usdt, 1 ether);
  }

  function testCorrectness_DepositNative_withGateway_ShouldWork() external {
    // 1. deposit bnb = 1 ether, worker should have 1 wbnb
    _depositNativeGateway(address(this), 1 ether);
  }

  function testCorrectness_WithdrawToken_withGateway_ShouldWork() external {
    // assume 1 bnb ~= 326 usdt
    // 1. deposit wbnb = 1 ether, usdt = 326 ether. expect withdraw and token out is "wbnb" should work
    _depositGateway(address(this), wbnb, 1 ether);
    _depositGateway(address(this), usdt, 326 ether);
    uint256 _share = vaultToken.balanceOf(address(this));
    _withdrawGateway(address(this), _share, address(wbnb));

    // 2. deposit wbnb = 1 ether, usdt = 326 ether. expect withdraw and token out is "usdt" should work
    _depositGateway(address(this), wbnb, 1 ether);
    _depositGateway(address(this), usdt, 326 ether);
    _share = vaultToken.balanceOf(address(this));
    _withdrawGateway(address(this), _share, address(usdt));

    // 3. deposit wbnb = 0 ether, usdt = 326 ether. expect withdraw and token out is "wbnb" should work
    _depositGateway(address(this), usdt, 326 ether);
    _share = vaultToken.balanceOf(address(this));
    _withdrawGateway(address(this), _share, address(wbnb));

    // 4. deposit wbnb = 1 ether, usdt = 0 ether. expect withdraw and token out is "usdt" should work
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
    _depositNativeGateway(address(this), 1 ether);
    uint256 _share = vaultToken.balanceOf(address(this));
    _withdrawNativeGateway(address(this), _share);
  }

  receive() external payable { }
}
