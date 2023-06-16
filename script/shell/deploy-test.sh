#!/bin/bash
source .env

forge script script/deployments/DeployProxyAdmin.s.sol --rpc-url local --broadcast
