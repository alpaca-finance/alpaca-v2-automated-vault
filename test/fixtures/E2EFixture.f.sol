// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// dependencies
import "@forge-std/Test.sol";

// contracts
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { AutomatedVaultERC20 } from "src/AutomatedVaultERC20.sol";
import { Bank } from "src/Bank.sol";
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { PancakeV3VaultOracle } from "src/oracles/PancakeV3VaultOracle.sol";
import { PCSV3Executor01 } from "src/executors/PCSV3Executor01.sol";

// interfaces
import { IERC20 } from "src/interfaces/IERC20.sol";
import { IExecutor } from "src/interfaces/IExecutor.sol";

// mocks
import { MockMoneyMarket } from "test/mocks/MockMoneyMarket.sol";

// fixtures
import "test/fixtures/BscFixture.f.sol";
import "test/fixtures/ProtocolActorFixture.f.sol";

// helpers
import { DeployHelper } from "test/helpers/DeployHelper.sol";

contract E2EFixture is Test, BscFixture, ProtocolActorFixture {
  uint16 internal constant TRADING_PERFORMANCE_FEE_BPS = 1_000;
  uint16 internal constant REWARD_PERFORMANCE_FEE_BPS = 1_000;
  uint16 internal constant MAX_PRICE_AGE = 60 * 60;
  uint16 internal constant MAX_PRICE_DIFF = 10_500;
  uint256 internal constant MIN_DEPOSIT = 1 ether;
  uint256 internal constant MANAGEMENT_FEE_PER_SEC = 0;
  uint16 internal constant WITHDRAWAL_FEE = 0;
  uint16 internal constant TOLERANCE_BPS = 9900; // tolerate up to 1% equity loss on manage
  uint8 internal constant MAX_LEVERAGE = 10;

  AutomatedVaultManager public vaultManager;
  MockMoneyMarket public moneyMarket;
  Bank public bank;
  PancakeV3VaultOracle public pancakeV3VaultOracle;
  PancakeV3Worker public workerUSDTWBNB;
  IExecutor public pancakeV3Executor;
  IERC20 public vaultToken;

  constructor() BscFixture() ProtocolActorFixture() {
    vm.createSelectFork("bsc_mainnet", BscFixture.FORK_BLOCK_NUMBER_1);

    vm.startPrank(DEPLOYER);

    vaultManager = AutomatedVaultManager(
      DeployHelper.deployUpgradeable(
        "AutomatedVaultManager",
        abi.encodeWithSelector(
          AutomatedVaultManager.initialize.selector,
          address(new AutomatedVaultERC20()),
          MANAGEMENT_FEE_TREASURY,
          WITHDRAWAL_FEE_TREASURY
        )
      )
    );

    moneyMarket = new MockMoneyMarket();

    bank = Bank(
      DeployHelper.deployUpgradeable(
        "Bank", abi.encodeWithSelector(Bank.initialize.selector, address(moneyMarket), address(vaultManager))
      )
    );

    pancakeV3VaultOracle = PancakeV3VaultOracle(
      DeployHelper.deployUpgradeable(
        "PancakeV3VaultOracle",
        abi.encodeWithSelector(
          PancakeV3VaultOracle.initialize.selector,
          address(pancakeV3PositionManager),
          address(bank),
          MAX_PRICE_AGE,
          MAX_PRICE_DIFF
        )
      )
    );
    pancakeV3VaultOracle.setPriceFeedOf(address(wbnb), address(wbnbFeed));
    pancakeV3VaultOracle.setPriceFeedOf(address(usdt), address(usdtFeed));

    workerUSDTWBNB = PancakeV3Worker(
      DeployHelper.deployUpgradeable(
        "PancakeV3Worker",
        abi.encodeWithSelector(
          PancakeV3Worker.initialize.selector,
          PancakeV3Worker.ConstructorParams({
            vaultManager: address(vaultManager),
            positionManager: address(pancakeV3PositionManager),
            pool: address(pancakeV3USDTWBNBPool),
            isToken0Base: true,
            router: address(pancakeV3Router),
            masterChef: address(pancakeV3MasterChef),
            zapV3: address(zapV3),
            performanceFeeBucket: PERFORMANCE_FEE_BUCKET,
            tradingPerformanceFeeBps: TRADING_PERFORMANCE_FEE_BPS,
            rewardPerformanceFeeBps: REWARD_PERFORMANCE_FEE_BPS,
            cakeToToken0Path: abi.encodePacked(address(cake), uint24(2500), address(usdt)),
            cakeToToken1Path: abi.encodePacked(address(cake), uint24(2500), address(wbnb))
          })
        )
      )
    );

    pancakeV3Executor = IExecutor(
      DeployHelper.deployUpgradeable(
        "PCSV3Executor01",
        abi.encodeWithSignature(
          "initialize(address,address,address)", address(vaultManager), address(bank), address(pancakeV3VaultOracle)
        )
      )
    );

    vaultToken = IERC20(
      vaultManager.openVault(
        "test vault",
        "TV",
        AutomatedVaultManager.VaultInfo({
          worker: address(workerUSDTWBNB),
          vaultOracle: address(pancakeV3VaultOracle),
          executor: address(pancakeV3Executor),
          minimumDeposit: MIN_DEPOSIT,
          capacity: type(uint256).max,
          managementFeePerSec: MANAGEMENT_FEE_PER_SEC,
          withdrawalFeeBps: WITHDRAWAL_FEE,
          toleranceBps: TOLERANCE_BPS,
          maxLeverage: MAX_LEVERAGE
        })
      )
    );
    vaultManager.setAllowToken(address(vaultToken), address(usdt), true);
    vaultManager.setVaultManager(address(vaultToken), MANAGER, true);

    vm.stopPrank();
  }
}
