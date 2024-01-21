// SPDX-License-Identifier: MIT
// Copyright (C) 2023
// tlend.s.sol : deploy tlend
//
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from
  "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Zap} from "src/zap.sol";
import {Leverager} from "src/leverager.sol";
import {Stargater} from "src/stargate.sol";
import {DlpStaker} from "src/stake.sol";
import {DlpToken, DlpTokenFab} from "src/dlp.sol";
import {DeployAAVE, IPoolAddressesProvider} from "./aave.s.sol";

contract DeployTLend is DeployAAVE {
  //////////////////////////////////////////////////////////////////////////
  ///  deploy tlen : zap, staker, stargate, leverage, liquidator, ...
  //////////////////////////////////////////////////////////////////////////
  address public swapNFT;
  address public swapRouter;
  address public stargateRouter;
  address public stargateETHRouter;

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
    dlpTokenFab.transferOwnership(address(staker));
  }

  function _deploy_stargate() internal {
    address pool = addressesProvider.getPool();
    bytes memory data = abi.encodeWithSignature(
      "initialize(address,address,address,address,address,uint256,uint256)",
      stargateRouter,
      stargateETHRouter,
      pool,
      address(weth),
      daoTreasury,
      0,
      20
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
      "initialize(address,address,address,uint256)", pool, address(weth), daoTreasury, 0
    );
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
      address(new Leverager()),
      deployer,
      data
    );
    leverager = Leverager(payable(address(proxy)));
  }

  function _deploy_dlp() internal {
    DlpToken dlpTokenImpl = new DlpToken();
    address incentivesController = addressesProvider.getAddress(keccak256("INCENTIVES_CONTROLLER"));
    dlpTokenFab = new DlpTokenFab(incentivesController, address(dlpTokenImpl));
  }

  function _deploy_sets() internal {
    // todo
  }

  function _deploy_set_provider_addresses() internal {
    bytes32 zapHash = keccak256("ZAP");
    addressesProvider.setAddress(zapHash, address(zap));

    bytes32 stakerHash = keccak256("STAKER");
    addressesProvider.setAddress(stakerHash, address(staker));

    bytes32 stargateHash = keccak256("STARGATE");
    addressesProvider.setAddress(stargateHash, address(stargater));

    bytes32 leveragerHash = keccak256("LEVERAGER");
    addressesProvider.setAddress(leveragerHash, address(leverager));

    bytes32 dlpTokenFabHash = keccak256("DLP_TOKEN_FAB");
    addressesProvider.setAddress(dlpTokenFabHash, address(dlpTokenFab));
  }

  function _deploy_tlen() internal {
    _deploy_dlp();
    _deploy_staker();
    _deploy_zap();
    if (!is_test) {
      _deploy_stargate();
    }
    _deploy_leverage();

    _deploy_set_provider_addresses();
    _deploy_sets();
  }

  function _before() internal override {
    super._before();
    swapNFT = vm.envAddress("SWAP_NFT");
    swapRouter = vm.envAddress("SWAP_ROUTER");
    stargateRouter = vm.envAddress("STARGATE_ROUTER");
    stargateETHRouter = vm.envAddress("STARGATE_ETH_ROUTER");
    addressesProvider = IPoolAddressesProvider(vm.envAddress("ADDRESSES_PROVIDER"));
  }

  function _run() internal virtual override {
    vm.startBroadcast(deployer);
    _deploy_tlen();
    vm.stopBroadcast();
  }
}
