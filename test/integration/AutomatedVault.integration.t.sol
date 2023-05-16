// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "test/base/BaseForkTest.sol";

// contracts
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { Bank } from "src/Bank.sol";
import { CommonV3LiquidityOracle } from "src/oracles/CommonV3LiquidityOracle.sol";
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { PancakeV3VaultOracle } from "src/oracles/PancakeV3VaultOracle.sol";
import { SimpleV3DepositExecutor } from "src/executors/SimpleV3DepositExecutor.sol";

// interfaces
import { IERC20 } from "src/interfaces/IERC20.sol";
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
  CommonV3LiquidityOracle pcsV3LiquidityOracle;
  PancakeV3Worker pcsV3Worker;
  PancakeV3VaultOracle pcsV3WorkerOracle;
  SimpleV3DepositExecutor depositExecutor;
  IERC20 vaultToken;

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

    pcsV3LiquidityOracle = deployLiquidityOracle(address(pancakeV3PositionManager), 6000, 10_500);
    pcsV3LiquidityOracle.setPriceFeedOf(address(wbnb), address(wbnbFeed));
    pcsV3LiquidityOracle.setPriceFeedOf(address(usdt), address(usdtFeed));

    vaultManager = deployAutomatedVaultManager();
    bank = deployBank(address(mockMoneyMarket), address(vaultManager));
    pcsV3Worker = deployPancakeV3Worker(
      PancakeV3Worker.ConstructorParams({
        vaultManager: vaultManager,
        positionManager: pancakeV3PositionManager,
        pool: pancakeV3USDTWBNBPool,
        router: pancakeV3Router,
        masterChef: pancakeV3MasterChef,
        zapV3: zapV3,
        performanceFeeBucket: PERFORMANCE_FEE_BUCKET,
        tickLower: TICK_LOWER,
        tickUpper: TICK_UPPER,
        performanceFeeBps: PERFORMANCE_FEE_BPS
      })
    );
    pcsV3WorkerOracle = new PancakeV3VaultOracle();

    depositExecutor = new SimpleV3DepositExecutor(address(bank));
    vaultToken = IERC20(
      vaultManager.openVault(
        "test vault",
        "TV",
        AutomatedVaultManager.VaultInfo({
          worker: address(pcsV3Worker),
          vaultOracle: address(pcsV3WorkerOracle),
          depositExecutor: address(depositExecutor)
        })
      )
    );

    vm.stopPrank();

    vm.startPrank(ALICE);
    wbnb.approve(address(vaultManager), 1 ether);
    usdt.approve(address(vaultManager), 2 ether);
    vm.stopPrank();
  }

  // TODO: revise this case after done with debt pricing
  function testCorrectness_VaultManager_DepositToEmptyVault_ShouldGetSharesEqualToEquity() public {
    IAutomatedVaultManager.DepositTokenParams[] memory deposits = new IAutomatedVaultManager.DepositTokenParams[](2);
    deposits[0] = IAutomatedVaultManager.DepositTokenParams({ token: address(wbnb), amount: 1 ether });
    deposits[1] = IAutomatedVaultManager.DepositTokenParams({ token: address(usdt), amount: 2 ether });

    uint256 _balanceWBNBBefore = wbnb.balanceOf(ALICE);
    uint256 _balanceUSDTBefore = usdt.balanceOf(ALICE);

    vm.prank(ALICE);
    (, uint256 amount0, uint256 amount1) =
      abi.decode(vaultManager.deposit(address(vaultToken), deposits, abi.encode()), (uint128, uint256, uint256));

    (, int256 usdtPrice,,,) = usdtFeed.latestRoundData();
    uint256 usdtValueUSD = amount0 * uint256(usdtPrice) / (10 ** usdtFeed.decimals());
    (, int256 wbnbPrice,,,) = wbnbFeed.latestRoundData();
    uint256 wbnbValueUSD = amount1 * uint256(wbnbPrice) / (10 ** wbnbFeed.decimals());
    uint256 expectedPositionValueUSD = usdtValueUSD + wbnbValueUSD;

    // check deducted user's balance
    assertEq(_balanceWBNBBefore - 1 ether, wbnb.balanceOf(ALICE));
    assertEq(_balanceUSDTBefore - 2 ether, usdt.balanceOf(ALICE));
    // check equity
    assertApproxEqAbs(
      pcsV3LiquidityOracle.getPositionValueUSD(address(pcsV3Worker.pool()), pcsV3Worker.nftTokenId()),
      expectedPositionValueUSD,
      327
    );
    // check vault token minted to user
    assertApproxEqAbs(vaultToken.balanceOf(ALICE), expectedPositionValueUSD, 327);
  }
}
