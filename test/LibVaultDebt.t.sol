// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/Test.sol";

import { LibVaultDebt } from "src/libraries/LibVaultDebt.sol";

// TODO: invariant test
contract LibVaultDebtUnitTest is Test {
  using LibVaultDebt for mapping(address => LibVaultDebt.VaultDebtList);

  mapping(address => LibVaultDebt.VaultDebtList) public vaultDebtLists;
  address vaultToken1 = makeAddr("vaultToken1");
  address vaultToken2 = makeAddr("vaultToken2");
  address token1 = makeAddr("token1");
  address token2 = makeAddr("token2");

  function testCorrectness_IncreaseDebtSharesOf() public {
    // Initialize vault1 debt list, add token1 to vault1 debt list
    // and increase token1 debt shares of vault1
    vaultDebtLists.increaseDebtSharesOf(vaultToken1, token1, 1 ether);

    // Expected link after: START <> TOKEN1 <> END

    // Walk forward: START > TOKEN1 > END
    assertEq(vaultDebtLists.getNextOf(vaultToken1, LibVaultDebt.START), token1, "START > TOKEN1");
    assertEq(vaultDebtLists.getNextOf(vaultToken1, token1), LibVaultDebt.END, "TOKEN1 > END");
    assertEq(vaultDebtLists.getNextOf(vaultToken1, LibVaultDebt.END), LibVaultDebt.START, "END > START");

    // Walk backward: START < TOKEN1 < END
    assertEq(vaultDebtLists.getPreviousOf(vaultToken1, LibVaultDebt.END), token1, "TOKEN1 < END");
    assertEq(vaultDebtLists.getPreviousOf(vaultToken1, token1), LibVaultDebt.START, "START < TOKEN1");
    assertEq(vaultDebtLists.getPreviousOf(vaultToken1, LibVaultDebt.START), LibVaultDebt.END, "END < START");

    // Token1 debt shares of vault1 should increased
    assertEq(vaultDebtLists.getDebtSharesOf(vaultToken1, token1), 1 ether, "token1 debt shares of vault1 increased 1");

    // Length of vault1 debt list should increased
    assertEq(vaultDebtLists.getLength(vaultToken1), 1, "vault1 list length increased");

    // Increase token1 debt shares of vault1
    vaultDebtLists.increaseDebtSharesOf(vaultToken1, token1, 1 ether);

    // Token1 debt shares of vault1 should increased
    assertEq(vaultDebtLists.getDebtSharesOf(vaultToken1, token1), 2 ether, "token1 debt shares of vault1 increased 2");

    // Everything else stays the same
    assertEq(vaultDebtLists.getNextOf(vaultToken1, LibVaultDebt.START), token1, "START > TOKEN1");
    assertEq(vaultDebtLists.getNextOf(vaultToken1, token1), LibVaultDebt.END, "TOKEN1 > END");
    assertEq(vaultDebtLists.getNextOf(vaultToken1, LibVaultDebt.END), LibVaultDebt.START, "END > START");

    assertEq(vaultDebtLists.getPreviousOf(vaultToken1, LibVaultDebt.END), token1, "TOKEN1 < END");
    assertEq(vaultDebtLists.getPreviousOf(vaultToken1, token1), LibVaultDebt.START, "START < TOKEN1");
    assertEq(vaultDebtLists.getPreviousOf(vaultToken1, LibVaultDebt.START), LibVaultDebt.END, "END < START");

    assertEq(vaultDebtLists.getLength(vaultToken1), 1, "vault1 list length increased");
  }

  function testCorrectness_DecreaseDebtSharesOf() public {
    vaultDebtLists.increaseDebtSharesOf(vaultToken1, token1, 1 ether);

    // Decrease token1 debt shares of vault1
    vaultDebtLists.decreaseDebtSharesOf(vaultToken1, token1, 0.5 ether);

    // Token1 debt shares of vault1 should decreased
    assertEq(vaultDebtLists.getDebtSharesOf(vaultToken1, token1), 0.5 ether, "token1 debt shares of vault1 decreased");

    // Everything else stays the same
    assertEq(vaultDebtLists.getNextOf(vaultToken1, LibVaultDebt.START), token1, "START > TOKEN1");
    assertEq(vaultDebtLists.getNextOf(vaultToken1, token1), LibVaultDebt.END, "TOKEN1 > END");
    assertEq(vaultDebtLists.getNextOf(vaultToken1, LibVaultDebt.END), LibVaultDebt.START, "END > START");

    assertEq(vaultDebtLists.getPreviousOf(vaultToken1, LibVaultDebt.END), token1, "TOKEN1 < END");
    assertEq(vaultDebtLists.getPreviousOf(vaultToken1, token1), LibVaultDebt.START, "START < TOKEN1");
    assertEq(vaultDebtLists.getPreviousOf(vaultToken1, LibVaultDebt.START), LibVaultDebt.END, "END < START");

    assertEq(vaultDebtLists.getLength(vaultToken1), 1, "vault1 list length remain the same");

    // Decrease token1 debt shares of vault1 to 0
    // Token1 should be removed from list as well
    // But vault1 list should remain initialized
    vaultDebtLists.decreaseDebtSharesOf(vaultToken1, token1, 0.5 ether);

    // Expected link after: START <> END
    assertEq(vaultDebtLists.getNextOf(vaultToken1, LibVaultDebt.START), LibVaultDebt.END, "START > END");
    assertEq(vaultDebtLists.getNextOf(vaultToken1, LibVaultDebt.END), LibVaultDebt.START, "START < END");
    assertEq(vaultDebtLists.getLength(vaultToken1), 0, "vault1 list length after remove token1");

    // TOKEN1 states should be gone
    assertEq(vaultDebtLists.getNextOf(vaultToken1, token1), LibVaultDebt.EMPTY, "TOKEN1 next gone");
    assertEq(vaultDebtLists.getPreviousOf(vaultToken1, token1), LibVaultDebt.EMPTY, "TOKEN1 prev gone");
    assertEq(vaultDebtLists.getDebtSharesOf(vaultToken1, token1), 0, "token1 debt shares of vault1 gone");
  }
}
