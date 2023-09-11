import { ICommonV3Pool__factory } from "./../../../typechain/factories/src/interfaces/ICommonV3Pool__factory";
import { IPancakeV3Factory__factory } from "./../../../typechain/factories/src/interfaces/pancake-v3/IPancakeV3Factory__factory";
import { ethers, upgrades } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ConfigFileHelper } from "../../file-helper/config-file-helper";
import { getDeployer } from "../../utils/deployer-helper";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";
import { compare } from "../../utils/address";

type PCSV3WorkerInitializeParam = {
  vaultManager: string;
  positionManager: string;
  pool: string;
  isToken0Base: boolean;
  router: string;
  masterChef: string;
  zapV3: string;
  performanceFeeBucket: string;
  tradingPerformanceFeeBps: number;
  rewardPerformanceFeeBps: number;
  cakeToToken0Path: string;
  cakeToToken1Path: string;
};

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const configFileHelper = new ConfigFileHelper();
  const config = configFileHelper.getConfig();
  const deployer = await getDeployer();

  const pancakeV3Factory = IPancakeV3Factory__factory.connect(config.dependencies.pancake.factoryV3, deployer);

  /*
  ░██╗░░░░░░░██╗░█████╗░██████╗░███╗░░██╗██╗███╗░░██╗░██████╗░
  ░██║░░██╗░░██║██╔══██╗██╔══██╗████╗░██║██║████╗░██║██╔════╝░
  ░╚██╗████╗██╔╝███████║██████╔╝██╔██╗██║██║██╔██╗██║██║░░██╗░
  ░░████╔═████║░██╔══██║██╔══██╗██║╚████║██║██║╚████║██║░░╚██╗
  ░░╚██╔╝░╚██╔╝░██║░░██║██║░░██║██║░╚███║██║██║░╚███║╚██████╔╝
  ░░░╚═╝░░░╚═╝░░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░╚══╝╚═╝╚═╝░░╚══╝░╚═════╝░
  Check all variables below before execute the deployment script
  */

  const POOL_FEE = 500;
  const BASE_TOKEN = config.tokens.wbnb;
  const OTHER_TOKEN = config.tokens.btcb;
  const TRADING_FEE_PERFORMANCE = 1500;
  const REWARD_FEE_PERFORMANCE = 1500;
  const PERFORMANCE_FEE_BUCKER = config.performanceFeeBucket;
  const CAKE_TO_TOKEN0_PATH = ethers.utils.solidityPack(
    ["address", "uint24", "address"],
    [config.tokens.cake, 500, config.tokens.wbnb]
  );
  const CAKE_TO_TOKEN1_PATH = ethers.utils.solidityPack(
    ["address", "uint24", "address", "uint24", "address"],
    [config.tokens.cake, 500, config.tokens.wbnb, 500, config.tokens.btcb]
  );

  const POOL_ADDRESS = await pancakeV3Factory.getPool(BASE_TOKEN, OTHER_TOKEN, POOL_FEE);
  const TOKEN0 = await ICommonV3Pool__factory.connect(POOL_ADDRESS, deployer).token0();
  const TOKEN1 = await ICommonV3Pool__factory.connect(POOL_ADDRESS, deployer).token1();

  const param: PCSV3WorkerInitializeParam = {
    vaultManager: config.automatedVault.automatedVaultManager.proxy,
    positionManager: config.dependencies.pancake.positionManager,
    router: config.dependencies.pancake.swapRouter,
    masterChef: config.dependencies.pancake.masterChef,
    zapV3: config.dependencies.zapV3,
    pool: POOL_ADDRESS,
    isToken0Base: compare(BASE_TOKEN, TOKEN0),
    performanceFeeBucket: PERFORMANCE_FEE_BUCKER,
    tradingPerformanceFeeBps: TRADING_FEE_PERFORMANCE,
    rewardPerformanceFeeBps: REWARD_FEE_PERFORMANCE,
    cakeToToken0Path: CAKE_TO_TOKEN0_PATH,
    cakeToToken1Path: CAKE_TO_TOKEN1_PATH,
  };

  console.log("Initializ param", param);

  const PancakeV3WorkerFactory = await ethers.getContractFactory("PancakeV3Worker", deployer);

  const pancakeV3Worker = await upgrades.deployProxy(PancakeV3WorkerFactory, [param]);

  const implAddress = await getImplementationAddress(ethers.provider, pancakeV3Worker.address);

  console.log(`> 🟢 PancakeV3Worker implementation deployed at: ${implAddress}`);
  console.log(`> 🟢 PancakeV3Worker proxy deployed at: ${pancakeV3Worker.address}`);

  configFileHelper.addVaultWorker(pancakeV3Worker.address, TOKEN0, TOKEN1);
};

export default func;
func.tags = ["PancakeV3WorkerDeploy"];
