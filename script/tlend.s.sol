// SPDX-License-Identifier: MIT
// Copyright (C) 2023
// tlend.s.sol : deploy tlend
//
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {DeployAAVE} from "./aave.s.sol";

contract DeployTLend is Script, DeployAAVE {
  //////////////////////////////////////////////////////////////////////////
  ///  deploy tlen : zap, staker, stargate, leverage, liquidator, ...
  //////////////////////////////////////////////////////////////////////////

  function _deploy_zap() internal {
    // todo
  }

  function _deploy_staker() internal {
    // todo
  }

  function _deploy_stargate() internal {
    // todo
  }

  function _deploy_leverage() internal {
    // todo
  }

  function _deploy_dlp() internal {
    // todo xx
  }

  function _deploy_tlen() internal {
    _deploy_zap();
    _deploy_staker();
    _deploy_stargate();
    _deploy_leverage();
    _deploy_dlp();
  }

  function _run() internal {
    _deploy_aave();
    _deploy_tlen();
  }

  function run() public {
    deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
    market_name = vm.envString("MARKET");
    network = vm.envString("NETWORK");
    weth = vm.envAddress("WETH");
    is_test = vm.envBool("TESTNET");
    l2_suppored = vm.envBool("L2_SUPPORTED");
    native = vm.envString("NATIVE");

    _before();

    vm.startBroadcast(deployer);

    _run();

    _after();

    vm.stopBroadcast();
  }
}
