// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

import { ERC20 } from "@solmate/tokens/ERC20.sol";

interface IWorker {
  function token0() external view returns (ERC20);

  function token1() external view returns (ERC20);

  function doWork(address user, uint256 _cmd, bytes calldata _params) external returns (bytes memory);
}
