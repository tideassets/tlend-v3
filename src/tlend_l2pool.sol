// SPDX-License-Identifier: MIT
// Copyright (C) 2023
// tlend_l2pool.sol : tlend pool on layer2
//
pragma solidity ^0.8.20;

import {L2Pool, IPoolAddressesProvider} from "@aave/core-v3/contracts/protocol/pool/L2Pool.sol";
import {Cross} from "./cross.sol";

contract TlendL2Pool is L2Pool {
  Cross cross;

  constructor(IPoolAddressesProvider provider) L2Pool(provider) {}

  function initialize(address addr_provider, address lz_endpoint) public initializer {
    // super.initialize(IPoolAddressesProvider(addr_provider));
    cross = new Cross(lz_endpoint, address(this));
  }

  function onReceiveMsg(
    uint16 src_chainId,
    bytes memory src_address,
    uint64 nonce,
    bytes memory payload
  ) external {}
}
