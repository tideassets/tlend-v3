// SPDX-License-Identifier: MIT
// Copyright (C) 2023
// swaprouter.sol : tswap router interface
//
pragma solidity ^0.8.20;

interface ISwapRouter {
  struct ExactOutputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint deadline;
    uint amountOut;
    uint amountInMaximum;
    uint160 sqrtPriceLimitX96;
  }

  /// @notice Swaps as little as possible of one token for `amountOut` of another token
  /// @param params The parameters necessary for the swap, encoded as `ExactOutputSingleParams` in calldata
  /// @return amountIn The amount of the input token
  function exactOutputSingle(ExactOutputSingleParams calldata params)
    external
    payable
    returns (uint amountIn);
}
