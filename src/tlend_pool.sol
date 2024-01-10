// SPDX-License-Identifier: MIT
// Copyright (C) 2023
// tlend_pool.sol : tlend pool on layer1
//
pragma solidity ^0.8.20;

import {Pool, IPoolAddressesProvider} from "@aave/core-v3/contracts/protocol/pool/Pool.sol";
import {Cross} from "./cross.sol";

contract TlendPool is Pool {
  Cross cross;

  constructor(IPoolAddressesProvider provider) Pool(provider) {}

  function initialize(address addr_provide, address lz_endpoint) public {
    // this.super.initialize(IPoolAddressesProvider(addr_provide));
    cross = new Cross(lz_endpoint, address(this));
  }

  function onReceiveMsg(
    uint16 src_chainId,
    bytes memory src_address,
    uint64 nonce,
    bytes memory payload
  ) external {}

  // borrow asset to dst chain account
  function lzBorrow() external {}

  // loop deposit and  borrow for leverage
  function loop() external {}
  function loopETH() external {}
}
