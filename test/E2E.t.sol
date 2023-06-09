// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./fixtures/E2EFixture.f.sol";
import { IAutomatedVaultManager } from "src/interfaces/IAutomatedVaultManager.sol";

contract E2ETest is E2EFixture {
  constructor() E2EFixture() { }

  /// -------------------------------
  /// Test utilities
  /// -------------------------------

  function _depositUSDTAndAssert(address depositor, uint256 amount) internal {
    deal(address(usdt), depositor, amount);

    uint256 sharesBefore = vaultToken.balanceOf(depositor);
    uint256 workerUSDTBefore = usdt.balanceOf(address(workerUSDTWBNB));

    vm.startPrank(depositor);
    usdt.approve(address(vaultManager), amount);

    IAutomatedVaultManager.DepositTokenParams[] memory deposits = new IAutomatedVaultManager.DepositTokenParams[](1);
    deposits[0] = IAutomatedVaultManager.DepositTokenParams({ token: address(usdt), amount: amount });
    vaultManager.deposit(address(vaultToken), deposits, 0);
    vm.stopPrank();

    // Assertions
    // - undeployed usdt increase by deposited amount
    assertEq(usdt.balanceOf(address(workerUSDTWBNB)) - workerUSDTBefore, amount, "undeployed usdt increase");
    // - shares minted to depositor equal to usd value of 1 usdt (equity)
    (, int256 usdtAnswer,,,) = usdtFeed.latestRoundData();
    assertEq(
      vaultToken.balanceOf(depositor) - sharesBefore,
      amount * uint256(usdtAnswer) / (10 ** usdtFeed.decimals()),
      "shares received"
    );
  }

  function _withdrawAndAssert(address withdrawFor, uint256 withdrawAmount) internal {
    uint256 sharesBefore = vaultToken.balanceOf(withdrawFor);
    IPancakeV3MasterChef.UserPositionInfo memory userInfoBefore =
      pancakeV3MasterChef.userPositionInfos(workerUSDTWBNB.nftTokenId());
    (, uint256 wbnbDebtBefore) = bank.getVaultDebt(address(vaultToken), address(wbnb));
    (, uint256 usdtDebtBefore) = bank.getVaultDebt(address(vaultToken), address(usdt));
    uint256 workerUSDTBefore = usdt.balanceOf(address(workerUSDTWBNB));
    uint256 workerWBNBBefore = wbnb.balanceOf(address(workerUSDTWBNB));
    (uint256 equityBefore,) = pancakeV3VaultOracle.getEquityAndDebt(address(vaultToken), address(workerUSDTWBNB));
    uint256 totalSharesBefore = vaultToken.totalSupply();

    AutomatedVaultManager.WithdrawSlippage[] memory minAmountOuts;
    vaultManager.withdraw(address(vaultToken), withdrawAmount, minAmountOuts);

    uint256 totalSharesAfter = vaultToken.totalSupply();

    // Assertions
    // didn't assert user balance due withdraw in and out of range result are different
    // - user shares was burned
    assertEq(sharesBefore - vaultToken.balanceOf(withdrawFor), withdrawAmount, "shares burned");
    // - position decreased by withdrawn%
    IPancakeV3MasterChef.UserPositionInfo memory userInfoAfter =
      pancakeV3MasterChef.userPositionInfos(workerUSDTWBNB.nftTokenId());
    assertApproxEqAbs(
      userInfoBefore.liquidity * totalSharesAfter / totalSharesBefore, userInfoAfter.liquidity, 1, "liquidity decreased"
    );
    // - debt repaid by withdrawn%
    (, uint256 usdtDebtAfter) = bank.getVaultDebt(address(vaultToken), address(usdt));
    assertEq(usdtDebtBefore * totalSharesAfter / totalSharesBefore, usdtDebtAfter, "usdt repaid");
    (, uint256 wbnbDebtAfter) = bank.getVaultDebt(address(vaultToken), address(wbnb));
    assertEq(wbnbDebtBefore * totalSharesAfter / totalSharesBefore, wbnbDebtAfter, "wbnb repaid");
    // - undeployed funds decreased by withdrawn%
    assertEq(
      workerUSDTBefore * totalSharesAfter / totalSharesBefore,
      usdt.balanceOf(address(workerUSDTWBNB)),
      "undeployed usdt withdrawn"
    );
    assertEq(
      workerWBNBBefore * totalSharesAfter / totalSharesBefore,
      wbnb.balanceOf(address(workerUSDTWBNB)),
      "undeployed wbnb withdrawn"
    );
    // - equity reduced by approx withdrawn%
    (uint256 equityAfter,) = pancakeV3VaultOracle.getEquityAndDebt(address(vaultToken), address(workerUSDTWBNB));
    assertApproxEqRel(equityBefore * totalSharesAfter / totalSharesBefore, equityAfter, 2, "equity decreased");
  }

  /// -------------------------------
  /// Test cases
  /// -------------------------------

  function testCorrectness_Deposit_WhitelistedToken() public {
    _depositUSDTAndAssert(address(this), 1 ether);
  }

  function testRevert_Deposit_NonWhitelistedToken() public {
    // Blacklist usdt
    vm.prank(DEPLOYER);
    vaultManager.setAllowToken(address(vaultToken), address(usdt), false);

    deal(address(usdt), address(this), 1 ether);

    usdt.approve(address(vaultManager), 1 ether);
    IAutomatedVaultManager.DepositTokenParams[] memory deposits = new IAutomatedVaultManager.DepositTokenParams[](1);
    deposits[0] = IAutomatedVaultManager.DepositTokenParams({ token: address(usdt), amount: 1 ether });
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_TokenNotAllowed.selector);
    vaultManager.deposit(address(vaultToken), deposits, 0);
  }

  function testRevert_Deposit_EquityIncreaseLessThanMinDeposit() public {
    // MIN_DEPOSIT = 0.1 ether. set in E2Efixture.
    deal(address(usdt), address(this), 0.01 ether);

    usdt.approve(address(vaultManager), 0.01 ether);
    IAutomatedVaultManager.DepositTokenParams[] memory deposits = new IAutomatedVaultManager.DepositTokenParams[](1);
    deposits[0] = IAutomatedVaultManager.DepositTokenParams({ token: address(usdt), amount: 0.01 ether });
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_BelowMinimumDeposit.selector);
    vaultManager.deposit(address(vaultToken), deposits, 0);
  }

  function testCorrectness_Withdraw_All_NoUndeployedFunds_OnlyInPosition() public {
    // Deposit
    _depositUSDTAndAssert(address(this), 1 ether);

    // Borrow and open in-range position
    deal(address(wbnb), address(moneyMarket), 0.01 ether);
    bytes[] memory executorData = new bytes[](3);
    executorData[0] = abi.encodeCall(PCSV3Executor01.borrow, (address(wbnb), 0.01 ether));
    executorData[1] = abi.encodeCall(PCSV3Executor01.transferToWorker, (address(wbnb), 0.01 ether));
    executorData[2] = abi.encodeCall(PCSV3Executor01.openPosition, (-58000, -57750, 1 ether, 0.01 ether));
    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), executorData);

    uint256 usdtBefore = usdt.balanceOf(address(this));
    uint256 wbnbBefore = wbnb.balanceOf(address(this));

    _withdrawAndAssert(address(this), vaultToken.balanceOf(address(this)));
    // - user received usdt but not wbnb
    assertGt(usdt.balanceOf(address(this)), usdtBefore);
    assertEq(wbnb.balanceOf(address(this)), wbnbBefore);
  }

  function testCorrectness_Withdraw_Partial_UndeployedFundsGtWithdraw() public {
    // Deposit 100 USDT
    // Deploy only 30 USDT => 70 USDT undeployed
    // Withdraw 1 USDT

    // Deposit
    deal(address(usdt), address(this), 100 ether);
    usdt.approve(address(vaultManager), 100 ether);
    IAutomatedVaultManager.DepositTokenParams[] memory deposits = new IAutomatedVaultManager.DepositTokenParams[](1);
    deposits[0] = IAutomatedVaultManager.DepositTokenParams({ token: address(usdt), amount: 100 ether });
    vaultManager.deposit(address(vaultToken), deposits, 0);

    // Borrow and open in-range position
    deal(address(wbnb), address(moneyMarket), 0.1 ether);
    bytes[] memory executorData = new bytes[](3);
    executorData[0] = abi.encodeCall(PCSV3Executor01.borrow, (address(wbnb), 0.1 ether));
    executorData[1] = abi.encodeCall(PCSV3Executor01.transferToWorker, (address(wbnb), 0.1 ether));
    executorData[2] = abi.encodeCall(PCSV3Executor01.openPosition, (-58000, -57750, 30 ether, 0.1 ether));
    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), executorData);

    uint256 userUSDTBefore = usdt.balanceOf(address(this));
    uint256 userWBNBBefore = wbnb.balanceOf(address(this));

    _withdrawAndAssert(address(this), vaultToken.balanceOf(address(this)) / 100);
    // - user receive both tokens due to being in-range and partial withdraw
    assertGt(usdt.balanceOf(address(this)), userUSDTBefore);
    assertGt(wbnb.balanceOf(address(this)), userWBNBBefore);
  }

  function testCorrectness_Withdraw_Partial_UndeployedFundsLtWithdraw() public {
    // Deposit 100 USDT
    // Deploy 99.9 USDT => 0.1 USDT undeployed
    // Withdraw ~1 USDT

    // Deposit
    deal(address(usdt), address(this), 100 ether);
    usdt.approve(address(vaultManager), 100 ether);
    IAutomatedVaultManager.DepositTokenParams[] memory deposits = new IAutomatedVaultManager.DepositTokenParams[](1);
    deposits[0] = IAutomatedVaultManager.DepositTokenParams({ token: address(usdt), amount: 100 ether });
    vaultManager.deposit(address(vaultToken), deposits, 0);

    // Borrow and open in-range position
    deal(address(wbnb), address(moneyMarket), 0.3 ether);
    bytes[] memory executorData = new bytes[](3);
    executorData[0] = abi.encodeCall(PCSV3Executor01.borrow, (address(wbnb), 0.3 ether));
    executorData[1] = abi.encodeCall(PCSV3Executor01.transferToWorker, (address(wbnb), 0.3 ether));
    executorData[2] = abi.encodeCall(PCSV3Executor01.openPosition, (-58000, -57750, 99.9 ether, 0.3 ether));
    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), executorData);

    uint256 userUSDTBefore = usdt.balanceOf(address(this));
    uint256 userWBNBBefore = wbnb.balanceOf(address(this));

    _withdrawAndAssert(address(this), vaultToken.balanceOf(address(this)) / 100);
    // - user receive both tokens due to being in-range and partial withdraw
    assertGt(usdt.balanceOf(address(this)), userUSDTBefore);
    assertGt(wbnb.balanceOf(address(this)), userWBNBBefore);
  }

  function testRevert_Withdraw_MoreThanSharesOwned() public {
    // Deposit 0.1 USDT should get ~0.1 share
    // Withdraw 1 share should revert
    deal(address(usdt), address(this), 0.1 ether);
    usdt.approve(address(vaultManager), 0.1 ether);
    IAutomatedVaultManager.DepositTokenParams[] memory deposits = new IAutomatedVaultManager.DepositTokenParams[](1);
    deposits[0] = IAutomatedVaultManager.DepositTokenParams({ token: address(usdt), amount: 0.1 ether });
    vaultManager.deposit(address(vaultToken), deposits, 0);

    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_WithdrawExceedBalance.selector);
    AutomatedVaultManager.WithdrawSlippage[] memory minAmountOuts;
    vaultManager.withdraw(address(vaultToken), 1 ether, minAmountOuts);
  }

  function testRevert_Manage_TooMuchEquityLoss() public {
    // Deposit 0.1 USDT
    // Borrow 0.1 WBNB
    // Open in-range position
    // Should fail due to zap in swap fee eat into equity too much

    deal(address(usdt), address(this), 0.1 ether);
    usdt.approve(address(vaultManager), 0.1 ether);
    IAutomatedVaultManager.DepositTokenParams[] memory deposits = new IAutomatedVaultManager.DepositTokenParams[](1);
    deposits[0] = IAutomatedVaultManager.DepositTokenParams({ token: address(usdt), amount: 0.1 ether });
    vaultManager.deposit(address(vaultToken), deposits, 0);

    deal(address(wbnb), address(moneyMarket), 0.1 ether);
    bytes[] memory executorData = new bytes[](3);
    executorData[0] = abi.encodeCall(PCSV3Executor01.borrow, (address(wbnb), 0.1 ether));
    executorData[1] = abi.encodeCall(PCSV3Executor01.transferToWorker, (address(wbnb), 0.1 ether));
    executorData[2] = abi.encodeCall(PCSV3Executor01.openPosition, (-58000, -57750, 0.1 ether, 0.1 ether));
    vm.prank(MANAGER);
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_TooMuchEquityLoss.selector);
    vaultManager.manage(address(vaultToken), executorData);
  }
}
