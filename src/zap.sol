// SPDX-License-Identifier: MIT
// Copyright (C) 2023
// zap.sol : from radiant zapping, use your native token and TTL to add liquidity to tswap pools
//
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from
  "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IPool, DataTypes} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IAaveOracle} from "@aave/core-v3/contracts/interfaces/IAaveOracle.sol";
// import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";

import {ISwapNFT} from "./interface/swapNFT.sol";
import {ISwapPool} from "./interface/swapPool.sol";
import {ISwapRouter} from "./interface/swapRouter.sol";

interface IStaker {
  function lockLiquidity(address user, address pool, uint liquidity, uint tokenId) external;
}

/// @title Zap contract
contract Zap is Initializable, OwnableUpgradeable, PausableUpgradeable {
  using SafeERC20 for IERC20;

  /// @notice Borrow rate mode
  uint public constant VARIABLE_INTEREST_RATE_MODE = 2;

  /// @notice We don't utilize any specific referral code for borrows perfomed via zaps
  uint16 public constant REFERRAL_CODE = 0;

  uint public constant MIN_HEALTH_FACTOR = 1.1e18;

  /// @notice  pool address = lpPools[TOKEN_A][TOKEN_B]
  mapping(address => mapping(address => address)) public lpPools;
  mapping(address => uint24) poolsTickSpacing;

  /// @notice Lending Pool contract
  IPool public lendingPool;

  /// @notice tswap AMM router
  ISwapRouter public swapRouter;
  /// @notice liquidity mgr
  ISwapNFT public nft;
  /// @notice staker contract
  IStaker public staker;

  IAaveOracle public oracle;

  /**
   * Events **********************
   */
  /// @notice Emitted when zap is done
  event Zapped(
    address indexed _from,
    address indexed _tokenA,
    address indexed _tokenB,
    uint _amountA,
    uint _amountB
  );

  event Unzapped(
    address indexed _from,
    uint indexed _tokenId,
    address indexed _recipient,
    uint _amountA,
    uint _amountB
  );

  /**
   * Errors **********************
   */
  error AddressZero();

  constructor() {
    _disableInitializers();
  }

  function initialize(
    address _pool,
    address _oracle,
    address _staker,
    address _swapRouter,
    address _nft
  ) external initializer {
    if (_swapRouter == address(0)) revert AddressZero();
    if (_nft == address(0)) revert AddressZero();

    __Ownable_init(msg.sender);
    __Pausable_init();

    lendingPool = IPool(_pool);
    oracle = IAaveOracle(_oracle);
    swapRouter = ISwapRouter(_swapRouter);
    nft = ISwapNFT(_nft);
    staker = IStaker(_staker);
  }

  receive() external payable {}

  function setLendingPool(address _lendingPool) external onlyOwner {
    if (_lendingPool == address(0)) revert AddressZero();
    lendingPool = IPool(_lendingPool);
  }

  function setSwapRouter(address _swapRouter) external onlyOwner {
    if (_swapRouter == address(0)) revert AddressZero();
    swapRouter = ISwapRouter(_swapRouter);
  }

  function setLiquidityMgr(address _nft) external onlyOwner {
    if (_nft == address(0)) revert AddressZero();
    nft = ISwapNFT(_nft);
  }

  function setStaker(address _staker) external onlyOwner {
    if (_staker == address(0)) revert AddressZero();
    staker = IStaker(_staker);
  }

  /**
   * @notice Get Variable debt token address
   * @param _asset underlying.
   */
  function getVDebtToken(address _asset) external view returns (address) {
    DataTypes.ReserveData memory reserveData = lendingPool.getReserveData(_asset);
    return reserveData.variableDebtTokenAddress;
  }

  function setSwapPool(address pool) external onlyOwner {
    address token0 = ISwapPool(pool).token0();
    address token1 = ISwapPool(pool).token1();
    uint24 tickSpacing = uint24(ISwapPool(pool).tickSpacing());
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

  // borrow and swap t1 for t0
  function _borrowOrSwap(TokensInfo memory ti, bool useBorrow, bool useSwap, uint24 fee) internal {
    if (useBorrow) {
      lendingPool.borrow(
        ti.t0, ti.a0 - ti.bl0, VARIABLE_INTEREST_RATE_MODE, REFERRAL_CODE, msg.sender
      );
      (,,,,, uint healthFactor) = lendingPool.getUserAccountData(msg.sender);
      if (healthFactor < MIN_HEALTH_FACTOR) {
        revert InvalidAmount();
      }
      IERC20(ti.t0).safeTransferFrom(msg.sender, address(this), ti.a0);
      IERC20(ti.t1).safeTransferFrom(msg.sender, address(this), ti.a1);
    } else if (useSwap) {
      IERC20(ti.t0).safeTransferFrom(msg.sender, address(this), ti.a0);
      IERC20(ti.t1).safeTransferFrom(msg.sender, address(this), ti.bl1);
      IERC20(ti.t1).forceApprove(address(swapRouter), ti.bl1);
      uint amountIn = swapRouter.exactOutputSingle(
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
    } else {
      revert InvalidAmount();
    }
  }

  function _zap0(ZapInfo memory zi, uint24 fee) internal {
    if (zi.amountA == 0 || zi.amountB == 0) revert InvalidAmount();
    uint balanceA = IERC20(zi.tokenA).balanceOf(address(msg.sender));
    uint balanceB = IERC20(zi.tokenB).balanceOf(address(msg.sender));
    bool ba = zi.amountA > balanceA;
    bool bb = zi.amountB > balanceB;

    if (ba && bb) {
      if (!zi.useBorrow) revert InvalidAmount();
    }

    if (ba) {
      TokensInfo memory ti =
        TokensInfo(zi.tokenA, zi.tokenB, zi.amountA, zi.amountB, balanceA, balanceB);
      _borrowOrSwap(ti, zi.useBorrow, zi.useSwap, fee);
    } else if (bb) {
      TokensInfo memory ti =
        TokensInfo(zi.tokenB, zi.tokenA, zi.amountB, zi.amountA, balanceB, balanceA);
      _borrowOrSwap(ti, zi.useBorrow, zi.useSwap, fee);
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
    bool useBorrow; // if true, borrow token from lending pool
    bool useSwap; // if true, swap a token for another
    bool stake; // if true, stake liquidity
    address recipient;
  }

  function _isEqual(uint va, uint vb) internal pure returns (bool) {
    uint diff = va > vb ? va - vb : vb - va;
    uint maxVal = va > vb ? va : vb;
    return diff <= maxVal / 100;
  }

  function _adjustAssetAmounts(ZapInfo memory zi) internal view {
    uint pa = oracle.getAssetPrice(zi.tokenA);
    uint pb = oracle.getAssetPrice(zi.tokenB);
    uint va = zi.amountA * pa;
    uint vb = zi.amountB * pb;
    if (_isEqual(va, vb)) {
      return;
    }
    if (va > vb) {
      zi.amountB = va / pb;
    } else if (va < vb) {
      zi.amountA = vb / pa;
    }
  }

  function zap(ZapInfo memory zi) external whenNotPaused returns (uint) {
    if (zi.amountA == 0 && zi.amountB == 0) revert InvalidAmount();

    (address token0, address token1) =
      zi.tokenA < zi.tokenB ? (zi.tokenA, zi.tokenB) : (zi.tokenB, zi.tokenA);
    if (lpPools[token0][token1] == address(0)) {
      revert InvalidTokens();
    }

    ISwapPool pool = ISwapPool(lpPools[token0][token1]);
    _zap0(zi, pool.fee());

    address recipient = zi.stake ? address(this) : zi.recipient;
    (uint tokenId, uint128 liquidity, uint amount0, uint amount1) = _zap1(zi, pool, recipient);

    IERC20(zi.tokenA).safeTransfer(msg.sender, zi.amountA - amount0);
    IERC20(zi.tokenB).safeTransfer(msg.sender, zi.amountB - amount1);

    if (zi.stake) {
      nft.approve(address(staker), tokenId);
      staker.lockLiquidity(msg.sender, address(pool), liquidity, tokenId);
    }
    emit Zapped(msg.sender, zi.tokenA, zi.tokenB, amount0, amount1);
    return liquidity;
  }

  function unzap(uint tokenId, address recipient) external whenNotPaused returns (uint, uint) {
    require(nft.ownerOf(tokenId) == msg.sender, "Not owner of tokenID");
    (,,,,,,, uint128 liquidity,,,,) = nft.positions(tokenId);
    ISwapNFT.DecreaseLiquidityParams memory param = ISwapNFT.DecreaseLiquidityParams({
      tokenId: tokenId,
      liquidity: liquidity,
      amount0Min: 0,
      amount1Min: 0,
      deadline: block.timestamp
    });

    nft.decreaseLiquidity(param);
    (uint amount0, uint amount1) = nft.collect(
      ISwapNFT.CollectParams({
        tokenId: tokenId,
        recipient: recipient,
        amount0Max: type(uint128).max,
        amount1Max: type(uint128).max
      })
    );

    nft.burn(tokenId);
    emit Unzapped(msg.sender, tokenId, recipient, amount0, amount1);
    return (amount0, amount1);
  }

  function _zap1(ZapInfo memory zi, ISwapPool pool, address recipient)
    internal
    returns (uint, uint128, uint, uint)
  {
    ISwapNFT.MintParams memory params;
    {
      IERC20(zi.tokenA).forceApprove(address(pool), zi.amountA);
      IERC20(zi.tokenB).forceApprove(address(pool), zi.amountB);
      uint24 pts = uint24(pool.tickSpacing()) * poolsTickSpacing[address(pool)];
      params = ISwapNFT.MintParams({
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
    return nft.mint(params);
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
