// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "test/base/BaseForkTest.sol";

// contracts
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { Bank } from "src/Bank.sol";
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { SimpleV3DepositExecutor } from "src/executors/SimpleV3DepositExecutor.sol";

// interfaces
import { IAutomatedVaultManager } from "src/interfaces/IAutomatedVaultManager.sol";

// mocks
import { MockMoneyMarket } from "test/mocks/MockMoneyMarket.sol";

contract AutomatedVaultIntegrationForkTest is BaseForkTest {
  int24 internal constant TICK_LOWER = -58000;
  int24 internal constant TICK_UPPER = -57750;
  uint16 internal constant PERFORMANCE_FEE_BPS = 1_000;

  MockMoneyMarket mockMoneyMarket;
  AutomatedVaultManager vaultManager;
  Bank bank;
  PancakeV3Worker pcsV3Worker;
  SimpleV3DepositExecutor depositExecutor;
  address vaultToken;

  function setUp() public override {
    super.setUp();

    vm.createSelectFork("bsc_mainnet", 27_515_914);
    deal(address(wbnb), ALICE, 100 ether);
    deal(address(usdt), ALICE, 100 ether);

    vm.startPrank(DEPLOYER);

    address[] memory tokensToSeed = new address[](2);
    tokensToSeed[0] = address(wbnb);
    tokensToSeed[1] = address(usdt);
    mockMoneyMarket = deployAndSeedMockMoneyMarket(tokensToSeed);

    vaultManager = deployAutomatedVaultManager();
    bank = deployBank(address(mockMoneyMarket), address(vaultManager));
    pcsV3Worker = deployPancakeV3Worker(
      PancakeV3Worker.ConstructorParams({
        vaultManager: vaultManager,
        positionManager: pancakeV3PositionManager,
        pool: pancakeV3WBNBUSDTPool,
        router: pancakeV3Router,
        masterChef: pancakeV3MasterChef,
        zapV3: zapV3,
        performanceFeeBucket: PERFORMANCE_FEE_BUCKET,
        tickLower: TICK_LOWER,
        tickUpper: TICK_UPPER,
        performanceFeeBps: PERFORMANCE_FEE_BPS
      })
    );
    depositExecutor = new SimpleV3DepositExecutor(address(pcsV3Worker), address(bank));
    vaultToken = vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.VaultInfo({ worker: address(pcsV3Worker), depositExecutor: address(depositExecutor) })
    );

    vm.stopPrank();
  }

  function testCorrectness_DepositToVaultManager() public {
    IAutomatedVaultManager.DepositTokenParams[] memory deposits = new IAutomatedVaultManager.DepositTokenParams[](2);
    deposits[0] = IAutomatedVaultManager.DepositTokenParams({ token: address(wbnb), amount: 1 ether });
    deposits[1] = IAutomatedVaultManager.DepositTokenParams({ token: address(usdt), amount: 2 ether });

    uint256 _balanceWBNBBefore = wbnb.balanceOf(ALICE);
    uint256 _balanceUSDTBefore = usdt.balanceOf(ALICE);

    vm.startPrank(ALICE);
    wbnb.approve(address(vaultManager), 1 ether);
    usdt.approve(address(vaultManager), 2 ether);
    vaultManager.deposit(vaultToken, deposits, abi.encode());
    vm.stopPrank();

    // check deducted user's balance
    assertEq(_balanceWBNBBefore - 1 ether, wbnb.balanceOf(ALICE));
    assertEq(_balanceUSDTBefore - 2 ether, usdt.balanceOf(ALICE));

    // TODO: check vault token minted to user
    // TODO: check equity
  }
}
