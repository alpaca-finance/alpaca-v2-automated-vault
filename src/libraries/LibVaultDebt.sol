// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

library LibVaultDebt {
  address internal constant EMPTY = address(0);
  address internal constant START = address(1);
  address internal constant END = address(2);

  struct VaultDebtList {
    uint256 length;
    // token => debtShares
    mapping(address => uint256) debtShares;
    // token => previous debt token
    mapping(address => address) prev;
    // token => next debt token
    mapping(address => address) next;
  }

  function increaseDebtSharesOf(
    mapping(address => VaultDebtList) storage self,
    address _vaultToken,
    address _token,
    uint256 _sharesToIncrease
  ) internal {
    VaultDebtList storage info = self[_vaultToken];

    if (info.length == 0) {
      info.next[_token] = END;
      info.prev[_token] = START;
      info.next[END] = START;
      info.prev[END] = _token;
      info.next[START] = _token;
      info.prev[START] = END;
      unchecked {
        ++info.length;
      }
    } else if (info.next[_token] == EMPTY) {
      info.next[_token] = END;
      address _prevOfEnd = info.prev[END];
      info.prev[_token] = _prevOfEnd;
      info.next[_prevOfEnd] = _token;
      info.prev[END] = _token;
      unchecked {
        ++info.length;
      }
    }

    info.debtShares[_token] += _sharesToIncrease;
  }

  function decreaseDebtSharesOf(
    mapping(address => VaultDebtList) storage self,
    address _vaultToken,
    address _token,
    uint256 _sharesToDecrease
  ) internal {
    VaultDebtList storage info = self[_vaultToken];

    info.debtShares[_token] -= _sharesToDecrease;

    if (info.debtShares[_token] == 0) {
      address _prevOfToken = info.prev[_token];
      info.next[_prevOfToken] = END;
      info.prev[END] = _prevOfToken;
      delete info.next[_token];
      delete info.prev[_token];
      unchecked {
        --info.length;
      }
    }
  }

  function getLength(mapping(address => VaultDebtList) storage self, address _vaultToken)
    internal
    view
    returns (uint256)
  {
    return self[_vaultToken].length;
  }

  function getDebtSharesOf(mapping(address => VaultDebtList) storage self, address _vaultToken, address _token)
    internal
    view
    returns (uint256)
  {
    return self[_vaultToken].debtShares[_token];
  }

  function getNextOf(mapping(address => VaultDebtList) storage self, address _vaultToken, address _token)
    internal
    view
    returns (address)
  {
    return self[_vaultToken].next[_token];
  }

  function getPreviousOf(mapping(address => VaultDebtList) storage self, address _vaultToken, address _token)
    internal
    view
    returns (address)
  {
    return self[_vaultToken].prev[_token];
  }
}
