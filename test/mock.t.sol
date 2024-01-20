// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {ERC721, IERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPool, DataTypes} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {MockReserveConfiguration} from
  "@aave/core-v3/contracts/mocks/helpers/MockReserveConfiguration.sol";
import {IEACAggregatorProxy} from "src/interface/chainlink.sol";
import {ISwapNFT} from "src/interface/swapNFT.sol";
import {ISwapRouter} from "src/interface/swapRouter.sol";
import {ISwapPool} from "src/interface/swapPool.sol";
import {IStargateRouter} from "src/interface/stargate.sol";

contract StakerMock {
  using SafeERC20 for IERC20;

  TokenMock public token;
  IERC721 public nft;

  constructor(IERC721 nft_) {
    token = new TokenMock("DLP", "DLP");
    nft = nft_;
  }

  function lockLiquidity(address user, address pool, uint liquidity, uint tokenId) external {
    console2.log("lockLiquidity", user, pool, liquidity);
    require(nft.ownerOf(tokenId) == msg.sender, "Dlp: not owner");
    nft.safeTransferFrom(msg.sender, address(this), tokenId);
    token.mint(user, liquidity);
  }
}

contract SwapRouterMock is ISwapRouter {
  using SafeERC20 for IERC20;

  mapping(address => IEACAggregatorProxy) public oracles;

  function setOracle(address token, IEACAggregatorProxy oracle) external {
    oracles[token] = oracle;
  }

  function exactOutputSingle(ExactOutputSingleParams calldata params)
    external
    payable
    returns (uint amountIn)
  {
    console2.log("exactOutputSingle", params.tokenIn, params.tokenOut);
    int price0 = oracles[params.tokenIn].latestAnswer();
    int price1 = oracles[params.tokenOut].latestAnswer();
    amountIn = uint(params.amountOut) * uint(price0) / uint(price1);
    require(amountIn <= params.amountInMaximum, "invalid amountIn");
    IERC20(params.tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
    IERC20(params.tokenOut).safeTransfer(msg.sender, params.amountOut);
  }
}

contract SwapNFTMock is ERC721, ISwapNFT {
  using SafeERC20 for IERC20;

  struct Position {
    uint96 nonce;
    address operator;
    address token0;
    address token1;
    uint24 fee;
    int24 tickLower;
    int24 tickUpper;
    uint128 liquidity;
    uint feeGrowthInside0LastX128;
    uint feeGrowthInside1LastX128;
    uint128 tokensOwed0;
    uint128 tokensOwed1;
  }

  uint public id;
  uint public totalSupply;
  mapping(uint => Position) public _positions;
  mapping(address => IEACAggregatorProxy) public oracles;

  constructor() ERC721("SwapNFTMock", "SWAP") {}

  function setOracle(address token, IEACAggregatorProxy oracle) external {
    oracles[token] = oracle;
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
  {
    console2.log("positions", tokenId);
    Position storage pos = _positions[tokenId];
    return (
      pos.nonce,
      pos.operator,
      pos.token0,
      pos.token1,
      pos.fee,
      pos.tickLower,
      pos.tickUpper,
      pos.liquidity,
      pos.feeGrowthInside0LastX128,
      pos.feeGrowthInside1LastX128,
      pos.tokensOwed0,
      pos.tokensOwed1
    );
  }

  function mint(MintParams calldata params)
    external
    payable
    returns (uint tokenId, uint128 liquidity, uint amount0, uint amount1)
  {
    console2.log("mint", params.token0, params.token1);

    id++;
    uint price0 = uint(oracles[params.token0].latestAnswer());
    uint price1 = uint(oracles[params.token1].latestAnswer());
    liquidity = uint128(price0 * params.amount0Desired + price1 * params.amount1Desired);

    Position storage pos = _positions[id];
    pos.nonce = uint96(block.timestamp);
    pos.operator = params.recipient;
    pos.token0 = params.token0;
    pos.token1 = params.token1;
    pos.fee = params.fee;
    pos.tickLower = params.tickLower;
    pos.tickUpper = params.tickUpper;
    pos.liquidity = liquidity;
    pos.tokensOwed0 = 0;
    pos.tokensOwed1 = 0;

    IERC20(params.token0).safeTransferFrom(msg.sender, address(this), params.amount0Desired);
    IERC20(params.token1).safeTransferFrom(msg.sender, address(this), params.amount1Desired);
    _mint(params.recipient, id);
    totalSupply += liquidity;

    return (id, liquidity, params.amount0Desired, params.amount1Desired);
  }

  function increaseLiquidity(IncreaseLiquidityParams calldata params)
    external
    payable
    returns (uint128 liquidity, uint amount0, uint amount1)
  {
    console2.log("increaseLiquidity", params.tokenId, params.amount0Desired, params.amount1Desired);
    Position storage pos = _positions[params.tokenId];
    uint price0 = uint(oracles[pos.token0].latestAnswer());
    uint price1 = uint(oracles[pos.token1].latestAnswer());
    liquidity = uint128(price0 * params.amount0Desired + price1 * params.amount1Desired);
    pos.liquidity += liquidity;
    return (liquidity, params.amount0Desired, params.amount1Desired);
  }

  function decreaseLiquidity(DecreaseLiquidityParams calldata params)
    external
    payable
    returns (uint amount0, uint amount1)
  {
    console2.log("decreaseLiquidity", params.tokenId, params.liquidity);
    require(ownerOf(params.tokenId) == msg.sender, "not owner");
    Position storage pos = _positions[params.tokenId];
    require(params.liquidity <= pos.liquidity, "invalid liquidity");
    pos.liquidity -= params.liquidity;
    totalSupply -= params.liquidity;
    uint price0 = uint(oracles[pos.token0].latestAnswer());
    uint price1 = uint(oracles[pos.token1].latestAnswer());
    amount0 = uint(params.liquidity / 2 / uint128(price0));
    amount1 = uint(params.liquidity / 2 / uint128(price1));
    pos.tokensOwed0 += uint128(amount0);
    pos.tokensOwed1 += uint128(amount1);
  }

  function collect(CollectParams calldata params)
    external
    payable
    returns (uint amount0, uint amount1)
  {
    console2.log("collect", params.tokenId, params.recipient);
    require(ownerOf(params.tokenId) == msg.sender, "not owner");
    Position storage pos = _positions[params.tokenId];
    require(pos.tokensOwed0 >= params.amount0Max, "invalid amount0");
    require(pos.tokensOwed1 >= params.amount1Max, "invalid amount1");
    pos.tokensOwed0 -= uint128(params.amount0Max);
    pos.tokensOwed1 -= uint128(params.amount1Max);
    IERC20(pos.token0).safeTransfer(params.recipient, params.amount0Max);
    IERC20(pos.token1).safeTransfer(params.recipient, params.amount1Max);
    amount0 = params.amount0Max;
    amount1 = params.amount1Max;
  }

  function burn(uint tokenId) external payable {
    console2.log("burn", tokenId);
    _burn(tokenId);
    delete _positions[tokenId];
  }
}

contract SwapPoolMock is ISwapPool {
  address public _fab;
  address public _token0;
  address public _token1;
  uint24 public _fee;
  int24 public _tickSpacing;
  uint128 public _maxLiquidityPerTick;

  constructor(address token0_, address token1_) {
    _token0 = token0_;
    _token1 = token1_;
    _fee = 3000;
    _tickSpacing = 100;
    _maxLiquidityPerTick = 1000000;
  }

  function factory() external view override returns (address) {
    return _fab;
  }

  function token0() external view override returns (address) {
    return _token0;
  }

  function token1() external view override returns (address) {
    return _token1;
  }

  function fee() external view override returns (uint24) {
    return _fee;
  }

  function tickSpacing() external view override returns (int24) {
    return _tickSpacing;
  }

  function maxLiquidityPerTick() external view override returns (uint128) {
    return _maxLiquidityPerTick;
  }
}

contract TokenMock is ERC20 {
  constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

  function mint(address usr, uint amount) external {
    _mint(usr, amount);
  }
}

contract OracleMock is IEACAggregatorProxy {
  int public price;
  uint8 public decimals_;
  uint public latestTimestamp_;
  uint public latestRound_;

  constructor(int price_) {
    price = price_;
    decimals_ = 8;
    latestTimestamp_ = block.timestamp;
    latestRound_ = 1;
  }

  function decimals() external view returns (uint8) {
    return decimals_;
  }

  function latestAnswer() external view returns (int) {
    return price;
  }

  function latestTimestamp() external view returns (uint) {
    return latestTimestamp_;
  }

  function latestRound() external view returns (uint) {
    return latestRound_;
  }

  function getAnswer(uint) external view returns (int) {
    return price;
  }

  function getTimestamp(uint) external view returns (uint) {
    return latestTimestamp_;
  }
}

contract LendPoolMock is MockReserveConfiguration {
  using SafeERC20 for IERC20;

  constructor() {}

  // function supply(address asset, uint amount, address onBehalfOf, uint16 referralCode) external {
  //   console2.log("supply", asset, amount);
  // }

  // function withdraw(address asset, uint amount, address to) external returns (uint) {
  //   console2.log("withdraw", asset, amount);
  //   return amount;
  // }

  function borrow(
    address asset,
    uint amount,
    uint interestRateMode,
    uint16 referralCode,
    address onBehalfOf
  ) external {
    console2.log("borrow", asset, amount);
    console2.log("borrow", interestRateMode, referralCode, onBehalfOf);

    TokenMock(asset).mint(onBehalfOf, amount);
  }

  // function repay(address asset, uint amount, uint interestRateMode, address onBehalfOf)
  //   external
  //   returns (uint)
  // {
  //   console2.log("repay", asset, amount);
  //   return amount;
  // }

  function getUserAccountData(address user)
    external
    pure
    returns (
      uint totalCollateralBase,
      uint totalDebtBase,
      uint availableBorrowsBase,
      uint currentLiquidationThreshold,
      uint ltv,
      uint healthFactor
    )
  {
    console2.log("getUserAccountData", user);
    totalCollateralBase = 1;
    totalDebtBase = 1;
    availableBorrowsBase = 1;
    currentLiquidationThreshold = 1;
    ltv = 10000;
    healthFactor = 11000;
  }

  function getConfiguration(address asset)
    public
    view
    returns (DataTypes.ReserveConfigurationMap memory)
  {
    console2.log("getConfiguration", asset);
    return configuration;
  }
}

contract AAVEOracleMock {
  mapping(address => uint) prices;

  constructor() {}

  function setAssetPrice(address asset, uint price) external {
    console2.log("setAssetPrice", asset, price);
    prices[asset] = price;
  }

  function getAssetPrice(address asset) external view returns (uint) {
    console2.log("getAssetPrice", asset);
    return prices[asset];
  }
}

contract StargateRouterMock {
  using SafeERC20 for IERC20;
  // ass = assets[chainId][poolId]

  mapping(uint => mapping(uint => address)) public assets;

  function setAsset(uint chainId, uint poolId, address asset) external {
    assets[chainId][poolId] = asset;
  }

  function swap(
    uint16 _dstChainId,
    uint _srcPoolId,
    uint _dstPoolId,
    address payable _refundAddress,
    uint _amountLD,
    uint _minAmountLD,
    IStargateRouter.lzTxObj memory,
    bytes calldata _to,
    bytes calldata
  ) external payable {
    console2.log("swap", _dstChainId, _srcPoolId, _dstPoolId);
    console2.log("swap", _refundAddress, _amountLD, _minAmountLD);
    address to = abi.decode(_to, (address));

    address asset = assets[_dstChainId][_dstPoolId];
    require(asset != address(0), "invalid chainId or poolId");
    IERC20(asset).safeTransfer(to, _amountLD);
  }
}

contract StargateETHRouterMock {
  function swapETH(
    uint16 _dstChainId, // destination Stargate chainId
    address payable _refundAddress, // refund additional messageFee to this address
    bytes calldata _toAddress, // the receiver of the destination ETH
    uint _amountLD, // the amount, in Local Decimals, to be swapped
    uint _minAmountLD // the minimum amount accepted out on destination
  ) external payable {
    console2.log("swapETH", _dstChainId, _amountLD, _minAmountLD);
    console2.log("swapETH", _refundAddress);
    address to = abi.decode(_toAddress, (address));
    payable(to).transfer(_amountLD);
  }
}

contract RewardsCtrlerMock {
  function claimRewards(address user, address[] calldata assets) external {
    console2.log("claimRewards", user);
  }
}
