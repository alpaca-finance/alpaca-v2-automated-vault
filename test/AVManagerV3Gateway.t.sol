// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./fixtures/E2EFixture.f.sol";
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { AVManagerV3Gateway, ERC20 } from "src/gateway/AVManagerV3Gateway.sol";
import { IAVManagerV3Gateway } from "src/interfaces/IAVManagerV3Gateway.sol";

contract AVManagerV3GatewayTest is E2EFixture {
  AVManagerV3Gateway internal avManagerV3Gateway;
  address public constant wNativeToken = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

  constructor() E2EFixture() {
    avManagerV3Gateway = new AVManagerV3Gateway(address(vaultManager), wNativeToken);
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

  function _withdrawConvertAll(address _caller, uint256 _share, bool _zeroForOne, uint256 _minAmountOut) internal {
    (address _worker,,,,,,,,) = vaultManager.vaultInfos(address(vaultToken));
    ERC20 _tokenOut = _zeroForOne ? PancakeV3Worker(_worker).token1() : PancakeV3Worker(_worker).token0();
    uint256 _userTokenOutBalanceBefore;
    // Check if wrap native
    if (address(_tokenOut) == wNativeToken) {
      _userTokenOutBalanceBefore = _caller.balance;
    } else {
      _userTokenOutBalanceBefore = _tokenOut.balanceOf(_caller);
    }

    uint256 _userVaultShareBefore = vaultToken.balanceOf(_caller);
    uint256 _totalVaultTokenBefore = vaultToken.totalSupply();

    vm.startPrank(_caller);
    vaultToken.approve(address(avManagerV3Gateway), _share);
    uint256 _amountOut = avManagerV3Gateway.withdrawConvertAll(address(vaultToken), _share, _zeroForOne, _minAmountOut);
    vm.stopPrank();

    uint256 _userVaultShareAfter = vaultToken.balanceOf(_caller);
    uint256 _totalVaultTokenAfter = vaultToken.totalSupply();
    uint256 _userTokenOutBalanceAfter;
    // Check if wrap native
    if (address(_tokenOut) == wNativeToken) {
      _userTokenOutBalanceAfter = _caller.balance;
    } else {
      _userTokenOutBalanceAfter = _tokenOut.balanceOf(_caller);
    }

    // user token out balance should increase
    assertEq(_userTokenOutBalanceAfter - _userTokenOutBalanceBefore, _amountOut);

    // user's decreasing share ~= vaultToken's decreasing share (assume management fee = 0)
    assertEq(_userVaultShareBefore - _userVaultShareAfter, _totalVaultTokenBefore - _totalVaultTokenAfter);

    // avManagerV3Gateway must have nothing
    assertEq(wbnb.balanceOf(address(avManagerV3Gateway)), 0);
    assertEq(usdt.balanceOf(address(avManagerV3Gateway)), 0);
  }

  function _withdrawMinimize(address _caller, uint256 _share, AutomatedVaultManager.TokenAmount[] memory _minAmountOuts)
    internal
  {
    uint256 _userVaultShareBefore = vaultToken.balanceOf(_caller);
    uint256 _totalVaultTokenBefore = vaultToken.totalSupply();

    vm.startPrank(_caller);
    vaultToken.approve(address(avManagerV3Gateway), _share);
    AutomatedVaultManager.TokenAmount[] memory _result =
      avManagerV3Gateway.withdrawMinimize(address(vaultToken), _share, _minAmountOuts);
    vm.stopPrank();
    uint256 _userVaultShareAfter = vaultToken.balanceOf(_caller);
    uint256 _totalVaultTokenAfter = vaultToken.totalSupply();

    // user's decreasing share ~= vaultToken's decreasing share (assume management fee = 0)
    assertEq(_userVaultShareBefore - _userVaultShareAfter, _totalVaultTokenBefore - _totalVaultTokenAfter);

    // avManagerV3Gateway must have nothing
    assertEq(wbnb.balanceOf(address(avManagerV3Gateway)), 0);
    assertEq(usdt.balanceOf(address(avManagerV3Gateway)), 0);
  }

  function testCorrectness_DepositToken_withGateway_ShouldWork() external {
    uint256 _amount = 1 ether;

    // 1. deposit wbnb = 1 ether, worker should have 1 wbnb
    _depositGateway(USER_ALICE, wbnb, _amount);
    assertEq(wbnb.balanceOf(address(workerUSDTWBNB)), _amount);

    // 2. deposit usdt = 1 ether, worker should have 1 usdt
    _depositGateway(USER_ALICE, usdt, _amount);
    assertEq(usdt.balanceOf(address(workerUSDTWBNB)), _amount);
  }

  function testCorrectness_DepositNative_withGateway_ShouldWork() external {
    // 1. deposit bnb = 1 ether, worker should have 1 wbnb
    uint256 _amount = 1 ether;
    _depositNativeGateway(USER_ALICE, _amount);

    assertEq(wbnb.balanceOf(address(workerUSDTWBNB)), _amount);
  }

  function testRevert_Deposit_InvalidInput() external {
    // erc20 token amount = 0
    vm.expectRevert(abi.encodeWithSelector(IAVManagerV3Gateway.AVManagerV3Gateway_InvalidInput.selector));
    avManagerV3Gateway.deposit(address(vaultToken), address(wbnb), 0, 0);

    // native
    vm.expectRevert(abi.encodeWithSelector(IAVManagerV3Gateway.AVManagerV3Gateway_InvalidInput.selector));
    avManagerV3Gateway.depositETH{ value: 0 }(address(vaultToken), 0);
  }

  function testCorrectness_WithdrawConvertAll_ShouldWork() external {
    uint256 _amount = 1 ether;
    // 1. deposit 1 wbnb, withdraw as token0
    _depositGateway(USER_ALICE, wbnb, _amount);
    uint256 _share = vaultToken.balanceOf(USER_ALICE);
    _withdrawConvertAll(USER_ALICE, _share, false, 0);

    // 2. deposit 1 wbnb, withdraw as token1
    _depositGateway(USER_ALICE, wbnb, _amount);
    _share = vaultToken.balanceOf(USER_ALICE);
    _withdrawConvertAll(USER_ALICE, _share, true, 0);

    // 3. deposit wbnb, usdt. withdraw as token0
    _depositGateway(USER_ALICE, wbnb, _amount);
    _depositGateway(USER_ALICE, usdt, _amount);
    _share = vaultToken.balanceOf(USER_ALICE);
    _withdrawConvertAll(USER_ALICE, _share, false, 0);

    // 4. deposit wbnb, usdt. withdraw as token1
    _depositGateway(USER_ALICE, wbnb, _amount);
    _depositGateway(USER_ALICE, usdt, _amount);
    _share = vaultToken.balanceOf(USER_ALICE);
    _withdrawConvertAll(USER_ALICE, _share, true, 0);
  }

  function testCorrectness_WithdrawMinimize_ShouldWork() external {
    uint256 _amount = 1 ether;

    // deposit 1 wbnb, 1 usdt
    _depositGateway(USER_ALICE, wbnb, _amount);
    _depositGateway(USER_ALICE, usdt, _amount);
    uint256 _share = vaultToken.balanceOf(USER_ALICE);
    AutomatedVaultManager.TokenAmount[] memory _minAmountOuts;
    _withdrawMinimize(USER_ALICE, _share, _minAmountOuts);

    // Expect
    // native bnb = 1 ether
    // wbnb = 0 (should not have token here)
    // usdt = 1 ether
    assertEq(USER_ALICE.balance, _amount);
    assertEq(wbnb.balanceOf(USER_ALICE), 0);
    assertEq(usdt.balanceOf(USER_ALICE), _amount);
  }

  function testRevert_WhenWithdrawAmountOut_IsLessThan_MinReceive() external {
    _depositGateway(USER_ALICE, wbnb, 1 ether);
    uint256 _share = vaultToken.balanceOf(USER_ALICE);

    // withdrawMinimize was tested by from AutomatedVaultManager.withdraw

    // withdrawConvertAll
    vm.startPrank(USER_ALICE);
    vaultToken.approve(address(avManagerV3Gateway), _share);
    vm.expectRevert(abi.encodeWithSelector(IAVManagerV3Gateway.AVManagerV3Gateway_TooLittleReceived.selector));
    avManagerV3Gateway.withdrawConvertAll(address(vaultToken), _share, true, 350 ether);
    vm.stopPrank();
  }

  receive() external payable { }
}
