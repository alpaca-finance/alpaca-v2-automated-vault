// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { AVManagerV3Gateway, ERC20 } from "src/gateway/AVManagerV3Gateway.sol";
import { BaseAVManagerV3Gateway, console } from "test/av-manager-v3-gateway/BaseAVManagerV3Gateway.sol";
import { ICommonV3Pool } from "src/interfaces/ICommonV3Pool.sol";
import { IAVManagerV3Gateway } from "src/interfaces/IAVManagerV3Gateway.sol";
import { MockPancakeV3Worker } from "test/mocks/MockPancakeV3Worker.sol";

contract AVManagerV3GatewayWithdrawTest is BaseAVManagerV3Gateway {
  address vaultToken;

  constructor() BaseAVManagerV3Gateway() { }

  function setUp() public {
    vaultToken = _openDefaultVault();
  }

  function testCorrectness_WithdrawConvertAll_Token0_ShouldWork() external {
    uint256 _amountToWithdraw = 1 ether;
    // deal vault share
    deal(address(vaultToken), USER_ALICE, _amountToWithdraw);

    // deal token to vault manager
    AutomatedVaultManager.TokenAmount[] memory withdrawResults = new AutomatedVaultManager.TokenAmount[](2);
    withdrawResults[0].token = address(wbnb);
    withdrawResults[0].amount = 1 ether;
    withdrawResults[1].token = address(usdt);
    withdrawResults[1].amount = 2 ether;
    mockVaultOracleAndExecutor.setOnTokenAmount(withdrawResults);
    deal(withdrawResults[0].token, address(vaultManager), withdrawResults[0].amount);
    deal(withdrawResults[1].token, address(vaultManager), withdrawResults[1].amount);

    mockWorker.setPool(address(pancakeV3USDTWBNBPool));
    mockWorker.setFee(500);

    // withdraw
    vm.startPrank(USER_ALICE);
    ERC20(vaultToken).approve(address(avManagerV3Gateway), _amountToWithdraw);
    uint256 _amountOut = avManagerV3Gateway.withdrawConvertAll(address(vaultToken), _amountToWithdraw, false, 0);
    vm.stopPrank();

    // assert usdt == amountOut
    assertEq(usdt.balanceOf(USER_ALICE), _amountOut);
  }

  function testCorrectness_WithdrawConvertAll_Token1_ShouldWork() external {
    uint256 _amountToWithdraw = 1 ether;
    // deal vault share
    deal(address(vaultToken), USER_ALICE, _amountToWithdraw);

    // deal token to vault manager
    AutomatedVaultManager.TokenAmount[] memory withdrawResults = new AutomatedVaultManager.TokenAmount[](2);
    withdrawResults[0].token = address(wbnb);
    withdrawResults[0].amount = 1 ether;
    withdrawResults[1].token = address(usdt);
    withdrawResults[1].amount = 2 ether;
    mockVaultOracleAndExecutor.setOnTokenAmount(withdrawResults);
    deal(withdrawResults[0].token, address(vaultManager), withdrawResults[0].amount);
    deal(withdrawResults[1].token, address(vaultManager), withdrawResults[1].amount);

    mockWorker.setPool(address(pancakeV3USDTWBNBPool));
    mockWorker.setFee(500);

    // withdraw
    vm.startPrank(USER_ALICE);
    ERC20(vaultToken).approve(address(avManagerV3Gateway), _amountToWithdraw);
    uint256 _amountOut = avManagerV3Gateway.withdrawConvertAll(address(vaultToken), _amountToWithdraw, true, 0);
    vm.stopPrank();

    // assert native balance == amountOut
    assertEq(USER_ALICE.balance, _amountOut);
  }

  function testCorrectness_WithdrawMinimize_ShouldWork() external {
    uint256 _amountToWithdraw = 1 ether;
    // get vault share
    deal(vaultToken, USER_ALICE, _amountToWithdraw, true);

    // prepare
    AutomatedVaultManager.TokenAmount[] memory withdrawResults = new AutomatedVaultManager.TokenAmount[](2);
    withdrawResults[0].token = address(wbnb);
    withdrawResults[0].amount = 1 ether;
    withdrawResults[1].token = address(usdt);
    withdrawResults[1].amount = 2 ether;
    mockVaultOracleAndExecutor.setOnTokenAmount(withdrawResults);
    deal(withdrawResults[0].token, address(vaultManager), withdrawResults[0].amount);
    deal(withdrawResults[1].token, address(vaultManager), withdrawResults[1].amount);

    // withdraw
    AutomatedVaultManager.TokenAmount[] memory _minAmountOuts;
    vm.startPrank(USER_ALICE);
    ERC20(vaultToken).approve(address(avManagerV3Gateway), _amountToWithdraw);
    avManagerV3Gateway.withdrawMinimize(address(vaultToken), _amountToWithdraw, _minAmountOuts);
    vm.stopPrank();

    // Expect
    // native bnb = 1 ether
    // wbnb = 0 (should not have token here)
    // usdt = 1 ether
    assertEq(USER_ALICE.balance, 1 ether);
    assertEq(wbnb.balanceOf(USER_ALICE), 0);
    assertEq(usdt.balanceOf(USER_ALICE), 2 ether);
  }

  function testRevert_WhenWithdrawAmountOut_IsLessThan_MinReceive() external {
    uint256 _amountToWithdraw = 1 ether;
    // get vault share
    deal(vaultToken, USER_ALICE, _amountToWithdraw, true);

    // withdrawMinimize was tested by from AutomatedVaultManager.withdraw

    // withdrawConvertAll
    // deal token to vault manager
    AutomatedVaultManager.TokenAmount[] memory withdrawResults = new AutomatedVaultManager.TokenAmount[](2);
    withdrawResults[0].token = address(wbnb);
    withdrawResults[0].amount = 1 ether;
    withdrawResults[1].token = address(usdt);
    withdrawResults[1].amount = 2 ether;
    mockVaultOracleAndExecutor.setOnTokenAmount(withdrawResults);
    deal(withdrawResults[0].token, address(vaultManager), withdrawResults[0].amount);
    deal(withdrawResults[1].token, address(vaultManager), withdrawResults[1].amount);

    mockWorker.setPool(address(pancakeV3USDTWBNBPool));
    mockWorker.setFee(500);

    // withdraw
    vm.startPrank(USER_ALICE);
    ERC20(vaultToken).approve(address(avManagerV3Gateway), _amountToWithdraw);
    vm.expectRevert(abi.encodeWithSelector(IAVManagerV3Gateway.AVManagerV3Gateway_TooLittleReceived.selector));
    avManagerV3Gateway.withdrawConvertAll(address(vaultToken), _amountToWithdraw, false, 400 ether);
    vm.stopPrank();
  }
}
