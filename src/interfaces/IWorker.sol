// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

import { Tasks } from "src/libraries/Constants.sol";

interface IWorker {
  function doWork(address user, Tasks _task, bytes calldata _params) external returns (bytes memory);
}
