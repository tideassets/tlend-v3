// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {ISwapNFT} from "../src/interface/swapNFT.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

interface IXXSwapNFT {
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

contract XXSwapNFT is IXXSwapNFT, ERC721 {
  constructor() ERC721("name", "symbol") {}

  function burn(uint tokenId) external payable {
    console2.log("XXSwapNFT: burn, %d", tokenId);
  }

  function collect(CollectParams calldata) external payable returns (uint amount0, uint amount1) {}

  function increaseLiquidity(IncreaseLiquidityParams calldata p)
    external
    payable
    returns (uint128, uint, uint)
  {
    console2.log("XXSwapNFT: IncreaseLiquidity, %d", p.amount1Desired);
    return (0, 0, 0);
  }

  function decreaseLiquidity(DecreaseLiquidityParams calldata p)
    external
    payable
    returns (uint, uint)
  {
    console2.log("XXSwapNFT: decreaseLiquidity, %d", p.amount1Min);
    return (0, 0);
  }

  function mint(MintParams memory p)
    external
    payable
    returns (uint tokenId, uint128 liquidity, uint amount0, uint amount1)
  {
    console2.log("XXSwapNFT: mint, %d", p.amount0Desired);
    return (0, 0, 0, 0);
  }

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
    )
  {}
}

contract NFTTest is Test {
  function testA() external {
    // ISwapNFT nft0 = new XXSwapNFT();
    ISwapNFT nft = ISwapNFT(address(new XXSwapNFT()));
    ISwapNFT.MintParams memory m_param = ISwapNFT.MintParams({
      token0: address(0),
      token1: address(0),
      fee: 0,
      tickLower: 0,
      tickUpper: 0,
      amount0Desired: 1000000,
      amount1Desired: 0,
      amount0Min: 0,
      amount1Min: 0,
      recipient: address(0),
      deadline: block.timestamp
    });
    nft.mint(m_param);
    ISwapNFT.IncreaseLiquidityParams memory inc_param = ISwapNFT.IncreaseLiquidityParams({
      tokenId: 12340,
      amount0Desired: 0,
      amount1Desired: 1000000,
      amount0Min: 0,
      amount1Min: 0,
      deadline: block.timestamp
    });
    nft.increaseLiquidity(inc_param);
    ISwapNFT.DecreaseLiquidityParams memory dec_param = ISwapNFT.DecreaseLiquidityParams({
      tokenId: 1000,
      liquidity: 0,
      amount0Min: 0,
      amount1Min: 10000,
      deadline: block.timestamp
    });
    nft.decreaseLiquidity(dec_param);
    nft.burn(1000);
    console2.log("nft: %s", address(nft));
  }
}
