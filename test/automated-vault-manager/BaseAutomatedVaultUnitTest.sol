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
  MockVaultOracleAndExecutor mockVaultOracleAndExecutor;
  address mockWorker = makeAddr("mockWorker");
  MockERC20 mockToken0;
  MockERC20 mockToken1;

  uint256 internal constant DEFAULT_MINIMUM_DEPOSIT = 1 ether;
  uint8 internal constant DEFAULT_MAX_LEVERAGE = 10;
  uint16 internal constant DEFAULT_TOLERANCE_BPS = 9900;

  constructor() ProtocolActorFixture() {
    mockToken0 = new MockERC20("Mock Token0", "MTKN0", 18);
    mockToken1 = new MockERC20("Mock Token1", "MTKN1", 6);

    vm.startPrank(DEPLOYER);
    vaultManager = AutomatedVaultManager(
      DeployHelper.deployUpgradeable(
        "AutomatedVaultManager", abi.encodeWithSignature("initialize(address)", address(new AutomatedVaultERC20()))
      )
    );
    vm.stopPrank();

    mockVaultOracleAndExecutor = new MockVaultOracleAndExecutor(address(vaultManager));
  }

  function _openVault(address worker, uint256 minimumDeposit, uint16 toleranceBps, uint8 maxLeverage)
    internal
    returns (address vaultToken)
  {
    vm.startPrank(DEPLOYER);
    vaultToken = vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.VaultInfo({
        worker: worker,
        vaultOracle: address(mockVaultOracleAndExecutor),
        executor: address(mockVaultOracleAndExecutor),
        minimumDeposit: minimumDeposit,
        withdrawalFeeBps: 0,
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
    return _openVault(mockWorker, DEFAULT_MINIMUM_DEPOSIT, DEFAULT_TOLERANCE_BPS, DEFAULT_MAX_LEVERAGE);
  }
}
