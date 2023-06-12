// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { AutomatedVaultERC20 } from "src/AutomatedVaultERC20.sol";
import { IAutomatedVaultManager } from "src/interfaces/IAutomatedVaultManager.sol";

// fixtures
import "test/fixtures/ProtocolActorFixture.f.sol";

// helpers
import { DeployHelper } from "test/helpers/DeployHelper.sol";

// mocks
import { MockERC20 } from "test/mocks/MockERC20.sol";
import { MockVaultOracleAndExecutor } from "test/mocks/MockVaultOracleAndExecutor.sol";

contract BaseAutomatedVaultUnitTest is ProtocolActorFixture {
  AutomatedVaultManager vaultManager;
  address mockWorker = makeAddr("mockWorker");
  MockVaultOracleAndExecutor mockVaultOracleAndExecutor;
  MockERC20 mockToken0;
  MockERC20 mockToken1;

  uint256 internal constant DEFAULT_MINIMUM_DEPOSIT = 0.1 ether;
  uint8 internal constant DEFAULT_MAX_LEVERAGE = 10;
  uint16 internal constant DEFAULT_TOLERANCE_BPS = 9900;

  constructor() ProtocolActorFixture() {
    mockToken0 = new MockERC20("Mock Token0", "MTKN0", 18);
    mockToken1 = new MockERC20("Mock Token1", "MTKN1", 6);

    mockVaultOracleAndExecutor = new MockVaultOracleAndExecutor();

    vm.startPrank(DEPLOYER);
    vaultManager = AutomatedVaultManager(
      DeployHelper.deployUpgradeable("AutomatedVaultManager", abi.encodeWithSignature("initialize()"))
    );
    vaultManager.setVaultTokenImplementation(address(new AutomatedVaultERC20()));
    vm.stopPrank();
  }

  function _openVault(uint256 minimumDeposit, uint16 toleranceBps, uint8 maxLeverage)
    internal
    returns (address vaultToken)
  {
    vm.startPrank(DEPLOYER);
    vaultToken = vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.VaultInfo({
        worker: address(mockWorker),
        vaultOracle: address(mockVaultOracleAndExecutor),
        executor: address(mockVaultOracleAndExecutor),
        minimumDeposit: minimumDeposit,
        toleranceBps: toleranceBps,
        maxLeverage: maxLeverage
      })
    );
    vaultManager.setVaultManager(address(vaultToken), MANAGER, true);
    vaultManager.setAllowToken(address(vaultToken), address(mockToken0), true);
    vaultManager.setAllowToken(address(vaultToken), address(mockToken1), true);
    vm.stopPrank();
  }

  function _openDefaultVault() internal returns (address) {
    return _openVault(DEFAULT_MINIMUM_DEPOSIT, DEFAULT_TOLERANCE_BPS, DEFAULT_MAX_LEVERAGE);
  }
}
