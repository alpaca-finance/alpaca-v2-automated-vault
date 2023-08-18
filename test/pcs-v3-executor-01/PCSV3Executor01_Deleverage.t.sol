// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/Test.sol";

import { PCSV3Executor01 } from "src/executors/PCSV3Executor01.sol";
import { PancakeV3VaultOracle } from "src/oracles/PancakeV3VaultOracle.sol";
import { Bank } from "src/Bank.sol";
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "test/fixtures/BscFixture.f.sol";

contract PCSV3Executor01DeleverageForkTest is BscFixture {
  address manager = 0x6EB9bC094CC57e56e91f3bec4BFfe7D9B1802e38;
  Bank bank = Bank(0xD0dfE9277B1DB02187557eAeD7e25F74eF2DE8f3);
  AutomatedVaultManager avManager = AutomatedVaultManager(0x2A9614504A12de8a85207199CdE1860269411F71);
  PCSV3Executor01 executor = PCSV3Executor01(0x7B33803D350293b271080ea78bE9CB0395d6d7E1);
  PancakeV3VaultOracle oracle = PancakeV3VaultOracle(0xa51b8f7dF8474111C6beA5eB2Fe60061C03FCEaf);
  ProxyAdmin proxyAdmin = ProxyAdmin(0x743a4c3f70C629a8BB27c8cf61651fc7BfC25c27);
  address L_USDTBNB_05_PCS1 = 0xb08eE41e88A2820cd572B4f2DFc459549790F2D7;
  address L_USDTBNB_05_PCS1_WORKER = 0x463039266657602f60fc70De00553772f3cf4392;

  constructor() BscFixture() {
    uint256 FORK_BLOCK_NUMBER = 30954637;
    vm.createSelectFork("bsc_mainnet", FORK_BLOCK_NUMBER);

    address newPCSV3Executor01 = address(new PCSV3Executor01());

    // upgrade Executor
    vm.startPrank(0xC44f82b07Ab3E691F826951a6E335E1bC1bB0B51);
    proxyAdmin.upgrade(ITransparentUpgradeableProxy(address(executor)), newPCSV3Executor01);
    // tolerance 1%
    avManager.setToleranceBps(L_USDTBNB_05_PCS1, 9900);
    vm.stopPrank();
  }

  function testFuzz_WhenDeleverage_DebtRatioShouldDecrease(uint256 _positionBps) public {
    _positionBps = bound(_positionBps, 1, 2500);

    bytes[] memory manageBytes = new bytes[](1);
    manageBytes[0] = abi.encodeCall(PCSV3Executor01.deleverage, (L_USDTBNB_05_PCS1, _positionBps));

    (, uint256 usdtDebtBefore) = bank.getVaultDebt(L_USDTBNB_05_PCS1, address(usdt));
    (, uint256 wbnbDebtBefore) = bank.getVaultDebt(L_USDTBNB_05_PCS1, address(wbnb));
    (uint256 vaultEquityBefore, uint256 vaultDebtBefore) =
      oracle.getEquityAndDebt(L_USDTBNB_05_PCS1, L_USDTBNB_05_PCS1_WORKER);

    vm.prank(manager);
    avManager.manage(L_USDTBNB_05_PCS1, manageBytes);

    (, uint256 usdtDebtAfter) = bank.getVaultDebt(L_USDTBNB_05_PCS1, address(usdt));
    (, uint256 wbnbDebtAfter) = bank.getVaultDebt(L_USDTBNB_05_PCS1, address(wbnb));
    (uint256 vaultEquityAfter, uint256 vaultDebtAfter) =
      oracle.getEquityAndDebt(L_USDTBNB_05_PCS1, L_USDTBNB_05_PCS1_WORKER);

    // debt and debt ratio should always decrease
    assertLt(usdtDebtAfter, usdtDebtBefore);
    assertLt(wbnbDebtAfter, wbnbDebtBefore);
    assertLt(
      
      vaultDebtAfter * 1 ether / (vaultEquityAfter + vaultDebtAfter),
      vaultDebtBefore * 1 ether / (vaultEquityBefore + vaultDebtBefore)
    );
  }
}
