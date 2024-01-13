// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";

import {
  StakerMock,
  SwapNFTMock,
  SwapRouterMock,
  LendPoolMock,
  TokenMock,
  OracleMock,
  AAVEOracleMock,
  SwapPoolMock,
  IERC20
} from "test/mock.t.sol";
import {Zap} from "src/Zap.sol";

contract ZapTest is Test {
  Zap public zap;
  IERC20 public token0;
  IERC20 public token1;
  IERC20 public asset0;
  IERC20 public asset1;
  IERC20 public asset3;

  function setUp() public {
    token0 = new TokenMock("Token0", "Token0");
    token1 = new TokenMock("Token1", "Token1");
    asset0 = new TokenMock("Asset0", "Asset0");
    asset1 = new TokenMock("Asset1", "Asset1");
    asset3 = new TokenMock("Asset3", "Asset3");
    zap = new Zap();

    OracleMock oracle0 = new OracleMock(1e8);
    OracleMock oracle1 = new OracleMock(1e8 * 2);

    LendPoolMock lendingPool = new LendPoolMock();
    AAVEOracleMock oracle = new AAVEOracleMock();
    SwapNFTMock nft = new SwapNFTMock();
    StakerMock staker = new StakerMock(nft);
    SwapRouterMock router = new SwapRouterMock();
    zap.initialize(
      address(lendingPool), address(oracle), address(staker), address(router), address(nft)
    );

    nft.setOracle(address(token0), oracle0);
    nft.setOracle(address(token1), oracle1);
    router.setOracle(address(token0), oracle0);
    router.setOracle(address(token1), oracle1);

    SwapPoolMock pool = new SwapPoolMock(address(token0), address(token1));
    zap.setSwapPool(address(pool));
    oracle.setAssetPrice(address(token0), 1e8);
    oracle.setAssetPrice(address(token1), 1e8 * 2);
  }

  function testZap000() public {
    Zap.ZapInfo memory zi = Zap.ZapInfo({
      recipient: address(this),
      tokenA: address(token0),
      tokenB: address(token1),
      amountA: 1e18,
      amountB: 2e18,
      useBorrow: false,
      useSwap: false,
      stake: false
    });
    zap.zap(zi);
  }

  function testZap100() public {
    Zap.ZapInfo memory zi = Zap.ZapInfo({
      recipient: address(this),
      tokenA: address(token0),
      tokenB: address(token1),
      amountA: 1e18,
      amountB: 2e18,
      useBorrow: true,
      useSwap: false,
      stake: false
    });
    zap.zap(zi);
  }

  function testZap010() public {
    Zap.ZapInfo memory zi = Zap.ZapInfo({
      recipient: address(this),
      tokenA: address(token0),
      tokenB: address(token1),
      amountA: 1e18,
      amountB: 2e18,
      useBorrow: false,
      useSwap: true,
      stake: false
    });
    zap.zap(zi);
  }

  function testZap110() public {
    Zap.ZapInfo memory zi = Zap.ZapInfo({
      recipient: address(this),
      tokenA: address(token0),
      tokenB: address(token1),
      amountA: 1e18,
      amountB: 2e18,
      useBorrow: true,
      useSwap: true,
      stake: false
    });
    zap.zap(zi);
  }

  function testZap001() public {
    Zap.ZapInfo memory zi = Zap.ZapInfo({
      recipient: address(this),
      tokenA: address(token0),
      tokenB: address(token1),
      amountA: 1e18,
      amountB: 2e18,
      useBorrow: false,
      useSwap: false,
      stake: true
    });
    zap.zap(zi);
  }

  function testZap101() public {
    Zap.ZapInfo memory zi = Zap.ZapInfo({
      recipient: address(this),
      tokenA: address(token0),
      tokenB: address(token1),
      amountA: 1e18,
      amountB: 2e18,
      useBorrow: true,
      useSwap: false,
      stake: true
    });
    zap.zap(zi);
  }

  function testZap011() public {
    Zap.ZapInfo memory zi = Zap.ZapInfo({
      recipient: address(this),
      tokenA: address(token0),
      tokenB: address(token1),
      amountA: 1e18,
      amountB: 2e18,
      useBorrow: false,
      useSwap: true,
      stake: true
    });
    zap.zap(zi);
  }

  function testZap111() public {
    Zap.ZapInfo memory zi = Zap.ZapInfo({
      recipient: address(this),
      tokenA: address(token0),
      tokenB: address(token1),
      amountA: 1e18,
      amountB: 2e18,
      useBorrow: true,
      useSwap: true,
      stake: true
    });
    zap.zap(zi);
  }
}
