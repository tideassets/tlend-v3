// SPDX-License-Identifier: MIT
// Copyright (C) 2023
// tlend.s.sol : deploy tlend
//
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from
  "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {DeployAAVE} from "./aave.s.sol";
import {Zap} from "src/zap.sol";
import {Leverager} from "src/leverager.sol";
import {Stargater} from "src/stargate.sol";
import {DlpStaker} from "src/stake.sol";
import {DlpToken, DlpTokenFab} from "src/dlp.sol";

contract DeployTLend is Script, DeployAAVE {
  //////////////////////////////////////////////////////////////////////////
  ///  deploy tlen : zap, staker, stargate, leverage, liquidator, ...
  //////////////////////////////////////////////////////////////////////////
  address public swapNFT;
  address public swapRouter;
  address public stargateRouter;
  address public stargateETHRouter;
  address public treasury;

  Zap public zap;
  DlpStaker public staker;
  DlpTokenFab public dlpTokenFab;
  Stargater public stargater;
  Leverager public leverager;

  function _deploy_zap() internal {
    address pool = addressesProvider.getPool();
    address aaveOracle = addressesProvider.getPriceOracle();
    bytes memory data = abi.encodeWithSignature(
      "initialize(address,address,address,address,address)",
      pool,
      aaveOracle,
      address(staker),
      swapRouter,
      swapNFT
    );
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
      address(new Zap()),
      deployer,
      data
    );
    zap = Zap(payable(address(proxy)));
    staker.setZap(address(zap));
  }

  function _deploy_staker() internal {
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
      address(new DlpStaker()),
      deployer,
      abi.encodeWithSignature("initialize(address,address)", swapNFT, address(dlpTokenFab))
    );
    staker = DlpStaker(payable(address(proxy)));
  }

  function _deploy_stargate() internal {
    address pool = addressesProvider.getPool();
    bytes memory data = abi.encodeWithSignature(
      "initialize(address,address,address,address,address,uint256,uint256)",
      stargater,
      stargateETHRouter,
      pool,
      address(weth),
      treasury,
      0,
      0
    );
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
      address(new Stargater()),
      deployer,
      data
    );
    stargater = Stargater(payable(address(proxy)));
  }

  function _deploy_leverage() internal {
    address pool = addressesProvider.getPool();
    bytes memory data = abi.encodeWithSignature(
      "initialize(address,address,address,uint256)", pool, address(weth), treasury, 0
    );
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
      address(new Stargater()),
      deployer,
      data
    );
    leverager = Leverager(payable(address(proxy)));
  }

  function _deploy_dlp() internal {
    DlpToken dlpTokenImpl = new DlpToken();
    dlpTokenFab = new DlpTokenFab(address(staker), address(dlpTokenImpl));
  }

  function _deploy_sets() internal {
    // todo
  }

  function _deploy_set_provider_addresses() internal {
    // todo
  }

  function _deploy_tlen() internal {
    _deploy_dlp();
    _deploy_staker();
    _deploy_zap();
    _deploy_stargate();
    _deploy_leverage();

    _deploy_set_provider_addresses();
    _deploy_sets();
  }

  function _run() internal virtual override {
    vm.startBroadcast(deployer);
    _deploy_tlen();
    vm.stopBroadcast();
  }
}
