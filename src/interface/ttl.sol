// SPDX-License-Identifier: MIT
// Copyright (C) 2023
// ttl.sol : interface of TTL token
//
pragma solidity ^0.8.20;

import {IOFTV2} from "@layerzerolabs/solidity-examples/contracts/token/oft/v2/interfaces/IOFTV2.sol";

interface ITTL is IOFTV2 {
  function mint(address to, uint amount) external;
  function burn(address from, uint amount) external;
}
