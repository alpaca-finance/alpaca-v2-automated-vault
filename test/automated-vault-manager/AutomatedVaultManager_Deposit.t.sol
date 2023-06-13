// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./BaseAutomatedVaultUnitTest.sol";

import { IERC20 } from "src/interfaces/IERC20.sol";

contract AutomatedVaultManagerDepositTest is BaseAutomatedVaultUnitTest {
  constructor() BaseAutomatedVaultUnitTest() { }

  function testRevert_WhenDepositToUnopenedVault() public {
    AutomatedVaultManager.DepositTokenParams[] memory _depositParams = new AutomatedVaultManager.DepositTokenParams[](0);
    vm.expectRevert(abi.encodeWithSignature("AutomatedVaultManager_VaultNotExist(address)", address(0)));
    vaultManager.deposit(address(0), _depositParams, 0);
  }

  function testRevert_WhenDepositTokenThatIsNotAllowed() public {
    address vaultToken = _openDefaultVault();
    vm.prank(DEPLOYER);
    vaultManager.setAllowToken(address(vaultToken), address(mockToken0), false);
    deal(address(mockToken0), address(this), 1 ether);

    IAutomatedVaultManager.DepositTokenParams[] memory params = new IAutomatedVaultManager.DepositTokenParams[](1);
    params[0] = IAutomatedVaultManager.DepositTokenParams({ token: address(mockToken0), amount: 1 ether });
    vm.expectRevert(abi.encodeWithSignature("AutomatedVaultManager_TokenNotAllowed()"));
    vaultManager.deposit(address(vaultToken), params, 0);
  }

  function testRevert_WhenDepositBelowMinimumDepositSize() public {
    address vaultToken = _openVault(mockWorker, 1 ether, DEFAULT_TOLERANCE_BPS, DEFAULT_MAX_LEVERAGE);
    uint256 equityAfter = 0.1 ether;

    mockVaultOracleAndExecutor.setGetEquityAndDebtResult({
      _equityBefore: 0,
      _debtBefore: 0,
      _equityAfter: equityAfter,
      _debtAfter: 0
    });

    IAutomatedVaultManager.DepositTokenParams[] memory params;
    vm.expectRevert(abi.encodeWithSignature("AutomatedVaultManager_BelowMinimumDeposit()"));
    vaultManager.deposit(vaultToken, params, 0);
  }

  function testRevert_ReceiveSharesLessThanMinReceive() public {
    address vaultToken = _openDefaultVault();
    uint256 sharesOut = 1 ether;

    mockVaultOracleAndExecutor.setGetEquityAndDebtResult({
      _equityBefore: 0,
      _debtBefore: 0,
      _equityAfter: sharesOut,
      _debtAfter: 0
    });

    IAutomatedVaultManager.DepositTokenParams[] memory params;
    vm.expectRevert(abi.encodeWithSignature("AutomatedVaultManager_TooLittleReceived()"));
    vaultManager.deposit(vaultToken, params, sharesOut + 1);
  }

  function testCorrectness_WhenDeposit_TokensShouldBeTransferred_ShouldReceiveSharesEqualToEquityChanged() public {
    address vaultToken = _openDefaultVault();
    uint256 equityChanged = 1 ether;
    uint256 depositAmount = 1 ether;
    deal(address(mockToken0), address(this), depositAmount);
    mockVaultOracleAndExecutor.setGetEquityAndDebtResult({
      _equityBefore: 0,
      _debtBefore: 0,
      _equityAfter: equityChanged,
      _debtAfter: 0
    });

    uint256 balanceBefore = mockToken0.balanceOf(address(this));

    IAutomatedVaultManager.DepositTokenParams[] memory params = new IAutomatedVaultManager.DepositTokenParams[](1);
    params[0].token = address(mockToken0);
    params[0].amount = depositAmount;
    mockToken0.approve(address(vaultManager), depositAmount);
    vaultManager.deposit(vaultToken, params, 0);

    // Assertions
    // - user balance deducted by depositAmount
    // - user receive shares equal to equity change
    assertEq(balanceBefore - mockToken0.balanceOf(address(this)), depositAmount);
    assertEq(IERC20(vaultToken).balanceOf(address(this)), equityChanged);

    // Invariant: EXECUTOR_IN_SCOPE == address(0)
    assertEq(vaultManager.EXECUTOR_IN_SCOPE(), address(0));
  }
}
