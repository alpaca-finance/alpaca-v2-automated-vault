// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "test/base/BaseTest.sol";

// dependencies
import { IViewFacet } from "@alpaca-mm/money-market/interfaces/IViewFacet.sol";

// contracts
import { Bank } from "src/Bank.sol";

// interfaces
import { IERC20 } from "src/interfaces/IERC20.sol";
import { IAutomatedVaultManager } from "src/interfaces/IAutomatedVaultManager.sol";

// libraries
import { LibShareUtil } from "src/libraries/LibShareUtil.sol";

// mocks
import { MockMoneyMarket } from "test/mocks/MockMoneyMarket.sol";

contract BankUnitTest is BaseTest {
  using LibShareUtil for uint256;

  Bank bank;
  MockMoneyMarket mockMoneyMarket;
  address vaultManager = makeAddr("vaultManager");
  address IN_SCOPE_EXECUTOR = makeAddr("IN_SCOPE_EXECUTOR");

  IERC20 wbnb;
  IERC20 usdt;

  function setUp() public override {
    super.setUp();

    vm.startPrank(DEPLOYER);

    wbnb = IERC20(deployMockERC20("mockBNB", "Mock BNB", 18));
    usdt = IERC20(deployMockERC20("mockUSDT", "Mock USDT", 6));

    address[] memory tokensToSeed = new address[](2);
    tokensToSeed[0] = address(wbnb);
    tokensToSeed[1] = address(usdt);
    mockMoneyMarket = deployAndSeedMockMoneyMarket(tokensToSeed);

    bank = deployBank(address(mockMoneyMarket), vaultManager);
    vm.stopPrank();

    vm.mockCall(
      address(vaultManager),
      abi.encodeWithSelector(IAutomatedVaultManager.EXECUTOR_IN_SCOPE.selector),
      abi.encode(IN_SCOPE_EXECUTOR)
    );

    deal(address(wbnb), IN_SCOPE_EXECUTOR, 100_000 ether);
    deal(address(usdt), IN_SCOPE_EXECUTOR, 100_000 ether);
  }

  function _doAndAssertBorrowOnBehalfOf(
    address vaultToken,
    address borrowToken,
    uint256 borrowAmount,
    uint256 expectedDebtSharesToIncrease
  ) internal {
    // Assertions
    // - borrower balance increase equal to input borrow amount
    // - vault debt shares increase equal to expected value
    // - vault debt amount increase equal to input borrow amount
    // - mm debt of bank increase equal to input borrow amount

    (uint256 prevDebtShares, uint256 prevDebtAmount) = bank.getVaultDebt(vaultToken, borrowToken);
    uint256 prevMMDebt = mockMoneyMarket.getNonCollatAccountDebt(address(bank), borrowToken);
    uint256 prevBalance = IERC20(borrowToken).balanceOf(IN_SCOPE_EXECUTOR);

    // Do borrowOnBehalfOf
    vm.prank(IN_SCOPE_EXECUTOR);
    bank.borrowOnBehalfOf(vaultToken, borrowToken, borrowAmount);

    (uint256 newDebtShares, uint256 newDebtAmount) = bank.getVaultDebt(vaultToken, borrowToken);

    // Borrower receive tokens equal to specified borrow amount
    assertEq(IERC20(borrowToken).balanceOf(IN_SCOPE_EXECUTOR) - prevBalance, borrowAmount, "borrower receive tokens");

    // Vault's debt shares should increase
    uint256 increasedVaultDebtShares = newDebtShares - prevDebtShares;
    assertEq(increasedVaultDebtShares, expectedDebtSharesToIncrease, "debt shares increase");

    // Vault's debt amount should increase equal to borrowed amount
    // Can tolerate 1 wei precision loss due to share to value conversion
    assertApproxEqAbs(newDebtAmount - prevDebtAmount, borrowAmount, 1, "debt amount increase");

    // MM non-collat token debt of bank should increase equal to borrowed amount
    uint256 mmTotalDebt = mockMoneyMarket.getNonCollatAccountDebt(address(bank), borrowToken);
    assertEq(mmTotalDebt - prevMMDebt, borrowAmount, "mm debt increase");
  }

  function testCorrectness_Subsequent_BorrowOnBehalfOf_ManyVault_ManyTokens_WithInterest() public {
    address vault1 = makeAddr("VAULT_1");
    address vault2 = makeAddr("VAULT_2");

    //////////////////////////////
    // First block, no interest //
    //////////////////////////////

    // Vault 1 first borrow, should get debt shares equal to borrowed amount
    _doAndAssertBorrowOnBehalfOf(vault1, address(wbnb), 1 ether, 1 ether);
    _doAndAssertBorrowOnBehalfOf(vault1, address(usdt), 1 ether, 1 ether);

    // Vault 2 first borrow, should get debt shares equal to borrowed amount
    _doAndAssertBorrowOnBehalfOf(vault2, address(wbnb), 1.5 ether, 1.5 ether);
    _doAndAssertBorrowOnBehalfOf(vault2, address(usdt), 1.5 ether, 1.5 ether);

    // Vault 1 Second borrow, should get debt shares equal to borrowed amount
    _doAndAssertBorrowOnBehalfOf(vault1, address(wbnb), 2 ether, 2 ether);
    _doAndAssertBorrowOnBehalfOf(vault1, address(usdt), 2 ether, 2 ether);

    // Vault 2 Second borrow, should get debt shares equal to borrowed amount
    _doAndAssertBorrowOnBehalfOf(vault2, address(wbnb), 2.5 ether, 2.5 ether);
    _doAndAssertBorrowOnBehalfOf(vault2, address(usdt), 2.5 ether, 2.5 ether);

    ////////////////////////////////////
    // Second block, interest accrued //
    ////////////////////////////////////

    // 1% interest accrued for wbnb
    mockMoneyMarket.pretendAccrueInterest(address(bank), address(wbnb), 0.07 ether);
    // 3% interest accrued for usdt
    mockMoneyMarket.pretendAccrueInterest(address(bank), address(usdt), 0.21 ether);

    // Borrow when there is interest, should get debt shares that doesn't account for previous borrow interest
    // expectedShares = borrowAmount * totalDebtShares / totalDebtAmount

    // expectedShares = 1 ether * 7 ether / 7.07 ether
    _doAndAssertBorrowOnBehalfOf(vault1, address(wbnb), 1 ether, 0.990099009900990099 ether);
    // expectedShares = 3 ether * 7 ether / 7.21 ether
    _doAndAssertBorrowOnBehalfOf(vault1, address(usdt), 3 ether, 2.91262135922330097 ether);
  }
}
