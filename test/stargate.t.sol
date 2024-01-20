// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";

import {TokenMock, StargateRouterMock, StargateETHRouterMock, LendPoolMock} from "test/mock.t.sol";
import {Stargater, IPool, WETH9, IStargateRouter, IRouterETH} from "src/stargate.sol";

contract StargaterTest is Test {
  Stargater public stargater;
  WETH9 public weth;
  TokenMock public token0;
  TokenMock public token1;

  function setUp() public {
    WETH9 _weth = new WETH9();
    IStargateRouter _router = IStargateRouter(address(new StargateRouterMock()));
    IRouterETH _eth_router = IRouterETH(address(new StargateETHRouterMock()));
    LendPoolMock pool = new LendPoolMock();
    token0 = new TokenMock("Token0", "T0");
    token1 = new TokenMock("Token1", "T1");

    stargater = new Stargater();
    stargater.initialize(_router, _eth_router, IPool(address(pool)), _weth, address(this), 100, 10);
  }

  function testBorrow() public {
    stargater.borrow(address(token0), 1e18, 2, 1);
  }

  function testBorrowETH() public {
    stargater.borrow(address(weth), 1e18, 2, 1);
  }
}
