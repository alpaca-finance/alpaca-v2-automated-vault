// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

library LibVaultDebt {
  error LibVaultDebt_EmptyList(address _vaultToken, address _token);

  address internal constant EMPTY = address(0);
  address internal constant START = address(1);
  address internal constant END = address(2);

  struct VaultDebtList {
    uint256 length;
    // debt token => debtShares
    mapping(address => uint256) debtShares;
    // debt token => previous debt token
    mapping(address => address) prev;
    // debt token => next debt token
    mapping(address => address) next;
  }

  /// @notice Increase debt shares of existing debt. Ensure that the list is initialized
  /// and debt exist before increase.
  function increaseDebtSharesOf(
    mapping(address => VaultDebtList) storage self,
    address _vaultToken,
    address _token,
    uint256 _sharesToIncrease
  ) internal {
    VaultDebtList storage info = self[_vaultToken];

    // Initialize list and add the first token
    if (info.length == 0) {
      // Expected link: START <> TOKEN <> END
      // with START <> END

      // Insert token between start and end
      info.next[_token] = END;
      info.prev[_token] = START;
      // Link end to start and token
      info.next[END] = START;
      info.prev[END] = _token;
      // Link start to token and end
      info.next[START] = _token;
      info.prev[START] = END;
      // Safe to use unchecked because length won't overflow uint256
      unchecked {
        ++info.length;
      }
    } else if (info.next[_token] == EMPTY) {
      // List is already initialized
      // Insert token at the end of list

      // Start link   : START <> ... PREV_TOKENS ... <> END
      // Expected link: START <> ... PREV_TOKENS ... <> NEW_TOKEN <> END

      // Add new token
      info.next[_token] = END;
      address _prevOfEnd = info.prev[END];
      info.prev[_token] = _prevOfEnd;
      // Update old links
      info.next[_prevOfEnd] = _token;
      info.prev[END] = _token;
      // Safe to use unchecked because length won't overflow uint256
      unchecked {
        ++info.length;
      }
    }

    // At this point vault debt list should be initialized and token should exist in link
    info.debtShares[_token] += _sharesToIncrease;
  }

  /// @notice Decrease debt shares of existing debt. If no debt shares remains after decreasing,
  /// remove that debt from the list. Revert upon empty or uninitialized list.
  /// Note that the list remain initialized even there is no debt.
  function decreaseDebtSharesOf(
    mapping(address => VaultDebtList) storage self,
    address _vaultToken,
    address _token,
    uint256 _sharesToDecrease
  ) internal {
    VaultDebtList storage info = self[_vaultToken];

    // Can't decrease empty / uninitialized list
    if (info.length == 0) {
      revert LibVaultDebt_EmptyList(_vaultToken, _token);
    }

    info.debtShares[_token] -= _sharesToDecrease;

    // Remove token from list if contains no debt shares
    if (info.debtShares[_token] == 0) {
      // Start link   : START <> PREV_OF_TOKEN <> TOKEN <> NEXT_OF_TOKEN <> END
      // Expected link: START <> PREV_OF_TOKEN <> NEXT_OF_TOKEN <> END

      // Remove token from list
      address _prevOfToken = info.prev[_token];
      address _nextOfToken = info.next[_token];
      info.next[_prevOfToken] = _nextOfToken;
      info.prev[_nextOfToken] = _prevOfToken;
      // Delete token data
      delete info.next[_token];
      delete info.prev[_token];
      // Safe to use unchecked since already check length before
      unchecked {
        --info.length;
      }
    }
  }

  /// @notice Get length of vault debt list.
  /// @param _vaultToken Vault to get length from.
  function getLength(mapping(address => VaultDebtList) storage self, address _vaultToken)
    internal
    view
    returns (uint256)
  {
    return self[_vaultToken].length;
  }

  /// @notice Get token debt shares of vault.
  /// @param _vaultToken Vault to get debt shares from.
  /// @param _token Token that vault is indebted to.
  function getDebtSharesOf(mapping(address => VaultDebtList) storage self, address _vaultToken, address _token)
    internal
    view
    returns (uint256)
  {
    return self[_vaultToken].debtShares[_token];
  }

  /// @notice Get the following token of input token. Return `END` if input token is the last.
  /// @param _vaultToken Vault to get token from.
  /// @param _token Token to get next token for.
  function getNextOf(mapping(address => VaultDebtList) storage self, address _vaultToken, address _token)
    internal
    view
    returns (address)
  {
    return self[_vaultToken].next[_token];
  }

  /// @notice Get the preceding token of input token. Return `START` if input token is the first.
  /// @param _vaultToken Vault to get token from.
  /// @param _token Token to get previous token for.
  function getPreviousOf(mapping(address => VaultDebtList) storage self, address _vaultToken, address _token)
    internal
    view
    returns (address)
  {
    return self[_vaultToken].prev[_token];
  }
}
