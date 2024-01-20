// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";

import {TokenMock, SwapPoolMock, SwapNFTMock, ISwapNFT, RewardsCtrlerMock} from "test/mock.t.sol";
import {DlpToken, DlpTokenFab} from "src/dlp.sol";
import {DlpStaker} from "src/stake.sol";

contract StakerTest is Test {
  DlpStaker public staker;
  TokenMock public token0;
  TokenMock public token1;
  SwapNFTMock public nft;

  function setUp() public {
    DlpToken dlpTokenImpl = new DlpToken();
    staker = new DlpStaker();
    nft = new SwapNFTMock();
    RewardsCtrlerMock rewardsCtrler = new RewardsCtrlerMock();
    DlpTokenFab dlpTokenFab = new DlpTokenFab(address(rewardsCtrler), address(dlpTokenImpl));
    staker.initialize(address(nft), address(dlpTokenFab));

    token0 = new TokenMock("T0", "T0");
    token1 = new TokenMock("T1", "T1");
  }

  function testLockLiquidity() public {
    SwapPoolMock pool = new SwapPoolMock(address(token0), address(token1));
    staker.setSwapPool(address(pool));
    ISwapNFT.MintParams memory params = ISwapNFT.MintParams({
      token0: address(token0),
      token1: address(token1),
      fee: 3000,
      tickLower: -887272,
      tickUpper: 887272,
      amount0Desired: 1e18,
      amount1Desired: 1e18,
      amount0Min: 0,
      amount1Min: 0,
      deadline: 0,
      recipient: address(this)
    });
    (uint tokenId, uint128 liquidity,,) = nft.mint(params);
    staker.lockLiquidity(address(pool), liquidity, tokenId);
  }
}
