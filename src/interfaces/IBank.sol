// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

interface IBank {
  function borrowOnBehalfOf(address _vaultToken, address _token, uint256 _amount) external;
  function repayOnBehalfOf(address _vaultToken, address _token, uint256 _amount) external;
  function accrueInterest(address _vaultToken) external;
  function getVaultDebt(address _vaultToken, address _token)
    external
    view
    returns (uint256 _debtShares, uint256 _debtAmount);
}
