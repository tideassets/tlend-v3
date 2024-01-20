// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";

import {LendPoolMock, TokenMock} from "test/mock.t.sol";
import {Leverager, WETH9, IPool} from "src/leverager.sol";

contract LeveragerTest is Test {
  Leverager public leverager;
  TokenMock public token0;
  TokenMock public token1;

  function setUp() public {
    leverager = new Leverager();
    LendPoolMock lendingPool = new LendPoolMock();
    WETH9 weth = new WETH9();
    leverager.initialize(address(lendingPool), address(weth), address(this), 100);

    lendingPool.setLtv(8000);
    lendingPool.setLiquidationBonus(10500);
    lendingPool.setLiquidationThreshold(8000);
    lendingPool.setDecimals(18);
    lendingPool.setFrozen(false);

    token0 = new TokenMock("T0", "T0");
    token0 = new TokenMock("T1", "T1");
  }

  function testLoop() public {
    leverager.loop(address(token0), 1e18, 2, 3);
  }

  function testLoopWithBorrow() public {
    leverager.loopWithBorrow(address(token0), 1e18, 2, 4);
  }
}
