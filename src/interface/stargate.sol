// SPDX-License-Identifier: MIT
// Copyright (C) 2023
// stargate.sol : copy from https://github.com/stargate-protocol/stargate/blob/main/contracts/interfaces/IStargateRouter.sol
//
pragma solidity ^0.8.20;
pragma abicoder v2;

interface IStargateRouter {
  struct lzTxObj {
    uint dstGasForCall;
    uint dstNativeAmount;
    bytes dstNativeAddr;
  }

  function addLiquidity(uint _poolId, uint _amountLD, address _to) external;

  function swap(
    uint16 _dstChainId,
    uint _srcPoolId,
    uint _dstPoolId,
    address payable _refundAddress,
    uint _amountLD,
    uint _minAmountLD,
    lzTxObj memory _lzTxParams,
    bytes calldata _to,
    bytes calldata _payload
  ) external payable;

  function redeemRemote(
    uint16 _dstChainId,
    uint _srcPoolId,
    uint _dstPoolId,
    address payable _refundAddress,
    uint _amountLP,
    uint _minAmountLD,
    bytes calldata _to,
    lzTxObj memory _lzTxParams
  ) external payable;

  function instantRedeemLocal(uint16 _srcPoolId, uint _amountLP, address _to)
    external
    returns (uint);

  function redeemLocal(
    uint16 _dstChainId,
    uint _srcPoolId,
    uint _dstPoolId,
    address payable _refundAddress,
    uint _amountLP,
    bytes calldata _to,
    lzTxObj memory _lzTxParams
  ) external payable;

  function sendCredits(
    uint16 _dstChainId,
    uint _srcPoolId,
    uint _dstPoolId,
    address payable _refundAddress
  ) external payable;

  function quoteLayerZeroFee(
    uint16 _dstChainId,
    uint8 _functionType,
    bytes calldata _toAddress,
    bytes calldata _transferAndCallPayload,
    lzTxObj memory _lzTxParams
  ) external view returns (uint, uint);
}

interface IRouterETH {
  function swapETH(
    uint16 _dstChainId, // destination Stargate chainId
    address payable _refundAddress, // refund additional messageFee to this address
    bytes calldata _toAddress, // the receiver of the destination ETH
    uint _amountLD, // the amount, in Local Decimals, to be swapped
    uint _minAmountLD // the minimum amount accepted out on destination
  ) external payable;
}
