// SPDX-License-Identifier: MIT
// Copyright (C) 2023
// cross.sol : use cross chain
//
pragma solidity ^0.8.20;

import {NonblockingLzApp} from
  "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IRecieveCallback {
  function onReceiveMsg(uint16, bytes memory, uint64, bytes memory) external;
}

contract Cross is NonblockingLzApp {
  IRecieveCallback recv_callback;

  constructor(address _endpoint, address callback) NonblockingLzApp(_endpoint) Ownable(msg.sender) {
    recv_callback = IRecieveCallback(callback);
  }

  function lzSend(
    uint16 _dstChainId,
    bytes memory _payload,
    address payable _refundAddress,
    address _zroPaymentAddress,
    bytes memory _adapterParams,
    uint _nativeFee
  ) external {
    _lzSend(_dstChainId, _payload, _refundAddress, _zroPaymentAddress, _adapterParams, _nativeFee);
  }

  function _nonblockingLzReceive(
    uint16 _srcChainId,
    bytes memory _srcAddress,
    uint64 _nonce,
    bytes memory _payload
  ) internal virtual override {
    recv_callback.onReceiveMsg(_srcChainId, _srcAddress, _nonce, _payload);
  }
}
