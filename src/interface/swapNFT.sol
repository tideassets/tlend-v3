// SPDX-License-Identifier: MIT
// Copyright (C) 2023
// nft.sol : tswap nft interface
//
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ISwapNFT is IERC721 {
  function positions(uint tokenId)
    external
    view
    returns (
      uint96 nonce,
      address operator,
      address token0,
      address token1,
      uint24 fee,
      int24 tickLower,
      int24 tickUpper,
      uint128 liquidity,
      uint feeGrowthInside0LastX128,
      uint feeGrowthInside1LastX128,
      uint128 tokensOwed0,
      uint128 tokensOwed1
    );

  struct MintParams {
    address token0;
    address token1;
    uint24 fee;
    int24 tickLower;
    int24 tickUpper;
    uint amount0Desired;
    uint amount1Desired;
    uint amount0Min;
    uint amount1Min;
    address recipient;
    uint deadline;
  }

  function mint(MintParams calldata params)
    external
    payable
    returns (uint tokenId, uint128 liquidity, uint amount0, uint amount1);

  struct IncreaseLiquidityParams {
    uint tokenId;
    uint amount0Desired;
    uint amount1Desired;
    uint amount0Min;
    uint amount1Min;
    uint deadline;
  }

  function increaseLiquidity(IncreaseLiquidityParams calldata params)
    external
    payable
    returns (uint128 liquidity, uint amount0, uint amount1);

  struct DecreaseLiquidityParams {
    uint tokenId;
    uint128 liquidity;
    uint amount0Min;
    uint amount1Min;
    uint deadline;
  }

  function decreaseLiquidity(DecreaseLiquidityParams calldata params)
    external
    payable
    returns (uint amount0, uint amount1);

  struct CollectParams {
    uint tokenId;
    address recipient;
    uint128 amount0Max;
    uint128 amount1Max;
  }

  function collect(CollectParams calldata params)
    external
    payable
    returns (uint amount0, uint amount1);

  function burn(uint tokenId) external payable;
}
