// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../fixtures/E2EFixture.f.sol";
import { VaultReader, IVaultReader } from "src/reader/VaultReader.sol";
import { LibTickMath } from "src/libraries/LibTickMath.sol";
import { LibSqrtPriceX96 } from "src/libraries/LibSqrtPriceX96.sol";

contract VaultReaderTest is E2EFixture {
  VaultReader vaultReader;
  uint256 constant MAX_BPS = 10000;

  constructor() E2EFixture() {
    vaultReader = new VaultReader(address(vaultManager), address(bank), address(pancakeV3VaultOracle));
  }

  function _depositUSDTAndAssert(address depositor, uint256 amount) internal {
    deal(address(usdt), depositor, amount);

    uint256 sharesBefore = vaultToken.balanceOf(depositor);
    uint256 workerUSDTBefore = usdt.balanceOf(address(workerUSDTWBNB));
    uint256 totalShareBefore = vaultToken.totalSupply();
    (uint256 equityBefore,) = pancakeV3VaultOracle.getEquityAndDebt(address(vaultToken), address(workerUSDTWBNB));
    (, int256 usdtAnswer,,,) = usdtFeed.latestRoundData();
    uint256 expectedEquityIncreased = amount * uint256(usdtAnswer) / (10 ** usdtFeed.decimals());
    uint256 expectedShareIncreased = equityBefore == 0
      ? expectedEquityIncreased
      : expectedEquityIncreased * (totalShareBefore + vaultManager.pendingManagementFee(address(vaultToken)))
        / equityBefore;

    vm.startPrank(depositor);
    usdt.approve(address(vaultManager), amount);

    AutomatedVaultManager.TokenAmount[] memory deposits = new AutomatedVaultManager.TokenAmount[](1);
    deposits[0] = AutomatedVaultManager.TokenAmount({ token: address(usdt), amount: amount });
    vaultManager.deposit(address(vaultToken), deposits, 0);
    vm.stopPrank();

    // Assertions
    // - undeployed usdt increase by deposited amount
    assertEq(usdt.balanceOf(address(workerUSDTWBNB)) - workerUSDTBefore, amount, "undeployed usdt increase");
    // - shares minted to depositor equal to usd value of 1 usdt (equity)
    assertEq(vaultToken.balanceOf(depositor) - sharesBefore, expectedShareIncreased, "shares received");
  }

  function _withdrawAndAssert(address withdrawFor, uint256 withdrawAmount) internal {
    {
      uint256 sharesBefore = vaultToken.balanceOf(withdrawFor);
      IPancakeV3MasterChef.UserPositionInfo memory userInfoBefore =
        pancakeV3MasterChef.userPositionInfos(workerUSDTWBNB.nftTokenId());
      (, uint256 wbnbDebtBefore) = bank.getVaultDebt(address(vaultToken), address(wbnb));
      (, uint256 usdtDebtBefore) = bank.getVaultDebt(address(vaultToken), address(usdt));
      uint256 workerUSDTBefore = usdt.balanceOf(address(workerUSDTWBNB));
      uint256 workerWBNBBefore = wbnb.balanceOf(address(workerUSDTWBNB));
      (uint256 equityBefore,) = pancakeV3VaultOracle.getEquityAndDebt(address(vaultToken), address(workerUSDTWBNB));
      uint256 totalSharesBefore = vaultToken.totalSupply() + vaultManager.pendingManagementFee(address(vaultToken));

      AutomatedVaultManager.TokenAmount[] memory minAmountOuts;
      vm.prank(withdrawFor);
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
        userInfoBefore.liquidity * totalSharesAfter / totalSharesBefore,
        userInfoAfter.liquidity,
        1,
        "liquidity decreased"
      );
      // - debt repaid by withdrawn%
      (, uint256 usdtDebtAfter) = bank.getVaultDebt(address(vaultToken), address(usdt));
      assertEq(usdtDebtBefore * totalSharesAfter / totalSharesBefore, usdtDebtAfter, "usdt repaid");
      (, uint256 wbnbDebtAfter) = bank.getVaultDebt(address(vaultToken), address(wbnb));
      assertEq(wbnbDebtBefore * totalSharesAfter / totalSharesBefore, wbnbDebtAfter, "wbnb repaid");
      // - undeployed funds decreased by withdrawn% (management fee will occur precision loss)

      uint256 expectedUsdtRemaining = (workerUSDTBefore * totalSharesAfter) / totalSharesBefore;
      uint256 expectedWbnbRemaining = (workerWBNBBefore * totalSharesAfter) / totalSharesBefore;

      // expect that maximum precision loss will be 1 wei
      assertApproxEqAbs(usdt.balanceOf(address(workerUSDTWBNB)), expectedUsdtRemaining, 1, "undeployed usdt withdrawn");
      assertApproxEqAbs(wbnb.balanceOf(address(workerUSDTWBNB)), expectedWbnbRemaining, 1, "undeployed wbnb withdrawn");

      // - equity reduced by approx withdrawn%
      (uint256 equityAfter,) = pancakeV3VaultOracle.getEquityAndDebt(address(vaultToken), address(workerUSDTWBNB));
      assertApproxEqRel(equityBefore * totalSharesAfter / totalSharesBefore, equityAfter, 2, "equity decreased");
    }

    (,,,,, uint256 withdrawalFeeBps,,) = vaultManager.vaultInfos(address(vaultToken));
    uint256 expectedShare = withdrawAmount * withdrawalFeeBps / MAX_BPS;

    // expect that withdrawal fee must be collected (if it's set)
    assertEq(vaultToken.balanceOf(WITHDRAWAL_FEE_TREASURY), expectedShare);
  }

  function test_VaultReader_ShouldWork() external {
    _depositUSDTAndAssert(address(this), 100 ether);

    // Open position with 100 USDT
    bytes[] memory executorData = new bytes[](1);
    executorData[0] = abi.encodeCall(PCSV3Executor01.openPosition, (-58000, -57750, 100 ether, 0));
    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), executorData);

    // Borrow 0.3 WBNB and increase position
    deal(address(wbnb), address(moneyMarket), 0.3 ether);
    executorData = new bytes[](3);
    executorData[0] = abi.encodeCall(PCSV3Executor01.borrow, (address(wbnb), 0.3 ether));
    executorData[1] = abi.encodeCall(PCSV3Executor01.transferToWorker, (address(wbnb), 0.3 ether));
    executorData[2] = abi.encodeCall(PCSV3Executor01.increasePosition, (0, 0.3 ether));
    vm.prank(MANAGER);
    vaultManager.manage(address(vaultToken), executorData);

    uint256 _token0price = pancakeV3VaultOracle.getTokenPrice(address(usdt));

    /// @dev please checks the return value in verbose (forge test -vvvvv)
    IVaultReader.VaultSummary memory vaultSummary = vaultReader.getVaultSummary(address(vaultToken));

    // assert vaultReader is working well. check from any value
    assertEq(vaultSummary.token0price, _token0price);
  }
}
