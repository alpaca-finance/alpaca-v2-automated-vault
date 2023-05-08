// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { StdCheats } from "@forge-std/StdCheats.sol";
import { Vm } from "@forge-std/Vm.sol";

import { IERC20 } from "src/interfaces/IERC20.sol";
import { IPancakeV3Router } from "src/interfaces/pancake-v3/IPancakeV3Router.sol";
import { IPancakeV3MasterChef } from "src/interfaces/pancake-v3/IPancakeV3MasterChef.sol";
import { ICommonV3PositionManager } from "src/interfaces/ICommonV3PositionManager.sol";
import { ICommonV3Pool } from "src/interfaces/ICommonV3Pool.sol";
import { IZapV3 } from "src/interfaces/IZapV3.sol";

abstract contract ForkTestConfigs is StdCheats {
  Vm private constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

  // Tokens
  IERC20 public constant wbnb = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
  IERC20 public constant usdt = IERC20(0x55d398326f99059fF775485246999027B3197955);

  // PancakeV3
  IPancakeV3Router public constant pancakeV3Router = IPancakeV3Router(0x13f4EA83D0bd40E75C8222255bc855a974568Dd4);
  ICommonV3PositionManager public constant pancakeV3PositionManager =
    ICommonV3PositionManager(0x46A15B0b27311cedF172AB29E4f4766fbE7F4364);
  IPancakeV3MasterChef public constant pancakeV3MasterChef =
    IPancakeV3MasterChef(0x556B9306565093C855AEA9AE92A594704c2Cd59e);

  // V3 pools
  // token0 = USDT, token1 = WBNB
  ICommonV3Pool public constant pancakeV3WBNBUSDTPool = ICommonV3Pool(0x36696169C63e42cd08ce11f5deeBbCeBae652050);

  // Zap
  IZapV3 public constant zapV3 = IZapV3(0xC462E9a70b16009d63fE9dFe701cA5bf70cBCb55);

  constructor() {
    vm.label(address(wbnb), "WBNB");
    vm.label(address(usdt), "USDT");

    vm.label(address(pancakeV3Router), "pancakeV3Router");
    vm.label(address(pancakeV3PositionManager), "pancakeV3PositionManager");
    vm.label(address(pancakeV3MasterChef), "pancakeV3MasterChef");

    vm.label(address(pancakeV3WBNBUSDTPool), "pancakeV3WBNBUSDTPool");

    vm.label(address(zapV3), "zapV3");
  }
}
