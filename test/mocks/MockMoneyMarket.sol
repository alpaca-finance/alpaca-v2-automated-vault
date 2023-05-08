// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IERC20 } from "src/interfaces/IERC20.sol";

contract MockMoneyMarket {
  function nonCollatBorrow(address _token, uint256 _amount) external {
    IERC20(_token).transfer(msg.sender, _amount);
  }
}
