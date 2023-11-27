// SPDX-License-Identifier: MIT
// Copyright (C) 2023
// zap.sol : from radiant zapping, use your native token and TTL to add liquidity to tswap pools
//

pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IPool, DataTypes} from "@aave/core-v3/contracts/interfaces/IPool.sol";

import {INFTMgr} from "./interface/nft.sol";
import {IV3Pool} from "./interface/v3pool.sol";
import {ISwapRouter} from "./interface/swaprouter.sol";

interface IStaker {
  function lockLiquidity(address user, address pool, uint liquidity, uint tokenId) external;
}

/// @title LockZap contract
contract LockZap is Initializable, OwnableUpgradeable, PausableUpgradeable {
  using SafeERC20 for IERC20;

  /// @notice Borrow rate mode
  uint256 public constant VARIABLE_INTEREST_RATE_MODE = 2;

  /// @notice We don't utilize any specific referral code for borrows perfomed via zaps
  uint16 public constant REFERRAL_CODE = 0;

  uint256 public constant MIN_HEALTH_FACTOR = 1.1e18;

  /// @notice  pool address = lpPools[TOKEN_A][TOKEN_B]
  mapping(address => mapping(address => address)) public lpPools;
  mapping(address => uint24) poolsTickSpacing;

  /// @notice Lending Pool contract
  IPool public lendingPool;

  /// @notice aave oracle contract
  // IAaveOracle public aaveOracle;
  // IPoolDataProvider public poolDataProvider;

  /// @notice tswap AMM router
  address public swapRouter;
  /// @notice liquidity mgr
  address public nftMgr;
  /// @notice staker contract
  address public staker;

  /********************** Events ***********************/
  /// @notice Emitted when zap is done
  event Zapped(
    address indexed _from,
    address indexed _tokenA,
    address indexed _tokenB,
    uint256 _amountA,
    uint256 _amountB
  );

  /********************** Errors ***********************/
  error AddressZero();

  constructor() {
    _disableInitializers();
  }

  function initialize(
    IPool _lendingPool,
    address _staker,
    address _swapRouter,
    address _nftMgr
  ) external initializer {
    if (address(_lendingPool) == address(0)) revert AddressZero();
    if (_swapRouter == address(0)) revert AddressZero();
    if (_nftMgr == address(0)) revert AddressZero();

    __Ownable_init(msg.sender);
    __Pausable_init();

    lendingPool = _lendingPool;
    swapRouter = _swapRouter;
    nftMgr = _nftMgr;
    staker = _staker;
  }

  receive() external payable {}

  function setLendingPool(address _lendingPool) external onlyOwner {
    if (_lendingPool == address(0)) revert AddressZero();
    lendingPool = IPool(_lendingPool);
  }

  function setSwapRouter(address _swapRouter) external onlyOwner {
    if (_swapRouter == address(0)) revert AddressZero();
    swapRouter = _swapRouter;
  }

  function setLiquidityMgr(address _nftMgr) external onlyOwner {
    if (_nftMgr == address(0)) revert AddressZero();
    nftMgr = _nftMgr;
  }

  /**
   * @notice Get Variable debt token address
   * @param _asset underlying.
   */
  function getVDebtToken(address _asset) external view returns (address) {
    DataTypes.ReserveData memory reserveData = lendingPool.getReserveData(_asset);
    return reserveData.variableDebtTokenAddress;
  }

  function setV3Pools(
    address tokenA,
    address tokenB,
    address pool, // if 0, remove
    uint24 tickSpacing
  ) external onlyOwner {
    if (tokenA == address(0)) revert AddressZero();
    if (tokenB == address(0)) revert AddressZero();
    (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    lpPools[token0][token1] = pool;
    poolsTickSpacing[pool] = tickSpacing;
  }

  error InvalidTokens();
  error InvalidAmount();
  struct TokensInfo {
    address t0;
    address t1;
    uint a0;
    uint a1;
    uint bl0;
    uint bl1;
  }

  function _borrowSwap(TokensInfo memory ti, bool isBorrow, uint24 fee) internal {
    if (isBorrow) {
      lendingPool.borrow(
        ti.t0,
        ti.a0 - ti.bl0,
        VARIABLE_INTEREST_RATE_MODE,
        REFERRAL_CODE,
        msg.sender
      );
      (, , , , , uint healthFactor) = lendingPool.getUserAccountData(msg.sender);
      if (healthFactor < MIN_HEALTH_FACTOR) {
        revert InvalidAmount();
      }
      IERC20(ti.t0).safeTransferFrom(msg.sender, address(this), ti.a0);
      IERC20(ti.t1).safeTransferFrom(msg.sender, address(this), ti.a1);
    } else {
      IERC20(ti.t0).safeTransferFrom(msg.sender, address(this), ti.a0);
      IERC20(ti.t1).safeTransferFrom(msg.sender, address(this), ti.bl1);
      IERC20(ti.t1).forceApprove(swapRouter, ti.bl1);
      uint amountIn = ISwapRouter(swapRouter).exactOutputSingle(
        ISwapRouter.ExactOutputSingleParams({
          tokenIn: ti.t1,
          tokenOut: ti.t0,
          fee: fee,
          recipient: msg.sender,
          deadline: block.timestamp,
          amountOut: ti.a0 - ti.bl0,
          amountInMaximum: ti.bl1,
          sqrtPriceLimitX96: 0
        })
      );
      if (ti.bl1 - amountIn < ti.a1) {
        revert InvalidAmount();
      }
      IERC20(ti.t1).safeTransfer(msg.sender, ti.bl1 - amountIn - ti.a1);
    }
  }

  function _zap0(ZapInfo memory zi, uint24 fee) internal {
    if (zi.amountA == 0 || zi.amountB == 0) revert InvalidAmount();
    uint balanceA = IERC20(zi.tokenA).balanceOf(address(msg.sender));
    uint balanceB = IERC20(zi.tokenB).balanceOf(address(msg.sender));
    bool ba = zi.amountA > balanceA;
    bool bb = zi.amountB > balanceB;

    if (ba && bb) {
      if (!zi.borrow) revert InvalidAmount();
    }
    if (ba || bb) {
      TokensInfo memory ti;
      if (ba) {
        ti = TokensInfo(zi.tokenA, zi.tokenB, zi.amountA, zi.amountB, balanceA, balanceB);
      } else {
        ti = TokensInfo(zi.tokenB, zi.tokenA, zi.amountB, zi.amountA, balanceB, balanceA);
      }
      _borrowSwap(ti, zi.borrow, fee);
    } else {
      IERC20(zi.tokenA).safeTransferFrom(msg.sender, address(this), zi.amountA);
      IERC20(zi.tokenB).safeTransferFrom(msg.sender, address(this), zi.amountB);
    }
  }

  struct ZapInfo {
    address tokenA;
    address tokenB;
    uint amountA;
    uint amountB;
    bool borrow;
    bool stake;
    address recipient;
  }

  //
  function zap(ZapInfo memory zi) external returns (uint) {
    if (zi.amountA == 0 || zi.amountB == 0) revert InvalidAmount();

    (address token0, address token1) = zi.tokenA < zi.tokenB
      ? (zi.tokenA, zi.tokenB)
      : (zi.tokenB, zi.tokenA);
    if (lpPools[token0][token1] == address(0)) revert InvalidTokens();

    IV3Pool pool = IV3Pool(lpPools[token0][token1]);
    _zap0(zi, pool.fee());

    address recipient = zi.stake ? address(this) : zi.recipient;
    (uint tokenId, uint128 liquidity, uint amount0, uint amount1) = _zap1(zi, pool, recipient);

    IERC20(zi.tokenA).safeTransfer(msg.sender, zi.amountA - amount0);
    IERC20(zi.tokenB).safeTransfer(msg.sender, zi.amountB - amount1);

    if (zi.stake) {
      INFTMgr(nftMgr).approve(staker, tokenId);
      IStaker(staker).lockLiquidity(msg.sender, address(pool), liquidity, tokenId);
    }
    emit Zapped(msg.sender, zi.tokenA, zi.tokenB, amount0, amount1);
    return liquidity;
  }

  function _zap1(
    ZapInfo memory zi,
    IV3Pool pool,
    address recipient
  ) internal returns (uint, uint128, uint, uint) {
    INFTMgr.MintParams memory params;
    {
      IERC20(zi.tokenA).forceApprove(address(pool), zi.amountA);
      IERC20(zi.tokenB).forceApprove(address(pool), zi.amountB);
      uint24 pts = uint24(pool.tickSpacing()) * poolsTickSpacing[address(pool)];
      params = INFTMgr.MintParams({
        token0: zi.tokenA,
        token1: zi.tokenB,
        fee: pool.fee(),
        tickLower: -int24(pts),
        tickUpper: int24(pts),
        amount0Desired: zi.amountA,
        amount1Desired: zi.amountB,
        amount0Min: 0,
        amount1Min: 0,
        recipient: recipient,
        deadline: block.timestamp
      });
    }
    return INFTMgr(nftMgr).mint(params);
  }

  /**
   * @notice Pause zapping operation.
   */
  function pause() external onlyOwner {
    _pause();
  }

  /**
   * @notice Unpause zapping operation.
   */
  function unpause() external onlyOwner {
    _unpause();
  }
}
