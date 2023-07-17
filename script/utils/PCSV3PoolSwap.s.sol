// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { ERC20 } from "lib/solmate/src/tokens/ERC20.sol";
import { IPancakeSwapRouterV3 } from
  "lib/alpaca-v2-money-market/solidity/contracts/money-market/interfaces/IPancakeSwapRouterV3.sol";

contract PCSV3PoolSwapScript is BaseScript {
  address internal constant PANCAKE_V3_ROUTER = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4;

  function run() public {
    address _tokenIn = usdt;
    address _tokenOut = wbnb;
    uint24 _fee = 500;
    uint256 _amountIn = 10000;

    vm.startBroadcast(deployerPrivateKey);

    IPancakeSwapRouterV3.ExactInputParams memory params = IPancakeSwapRouterV3.ExactInputParams({
      path: abi.encodePacked(_tokenIn, _fee, _tokenOut),
      recipient: vm.addr(deployerPrivateKey),
      deadline: 10000000,
      amountIn: _amountIn,
      amountOutMinimum: 0
    });

    ERC20(_tokenIn).approve(PANCAKE_V3_ROUTER, _amountIn);
    IPancakeSwapRouterV3(PANCAKE_V3_ROUTER).exactInput(params);

    vm.stopBroadcast();
  }
}
