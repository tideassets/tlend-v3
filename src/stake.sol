// SPDX-License-Identifier: MIT
// Copyright (C) 2023
// stake.sol : lock liquidity and redeem dlp token
//
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {DlpToken, DlpTokenFab} from "./dlp.sol";
import {ISwapNFT} from "./interface/swapNFT.sol";

interface IFundStaker {
  function stake(address usr, uint amount) external;
  function unstake(address usr, uint amount) external;
}

contract DlpStaker is OwnableUpgradeable {
  uint public DURATION = 30 days;
  address public zap;
  DlpTokenFab public dlpTokenFab;

  // tokenId => DlpParams
  mapping(uint => DlpParams) public dlpParams;
  // pool => DlpToken
  mapping(address => address) public dlpTokens;

  ISwapNFT public nft;

  struct DlpParams {
    address user;
    address pool;
    uint liquidity;
    uint end;
  }

  modifier onlyZap() {
    require(msg.sender == zap, "Dlp: not zap");
    _;
  }

  event DlpLocked(address indexed who, address indexed pool, uint indexed tokenId, uint liquidity);
  event DlpUnlocked(
    address indexed who, address indexed pool, uint indexed tokenId, uint liquidity
  );

  event SetSwapNFT(address indexed old, address indexed current);
  event SetSwapPool(address indexed pool, address indexed dlpToken);
  event SetDuration(uint indexed duration);
  event SetZap(address indexed zap);
  event SetDlpTokenImpl(address indexed old, address indexed impl);
  event SetRewardsController(address indexed old, address indexed current);

  function initialize(address _nftMgr, address _fab) public initializer {
    __Ownable_init(msg.sender);
    nft = ISwapNFT(_nftMgr);
    dlpTokenFab = DlpTokenFab(_fab);
  }

  function setZap(address _zap) external onlyOwner {
    zap = _zap;
    emit SetZap(_zap);
  }

  function setSwapPool(address pool) external onlyOwner {
    require(dlpTokens[pool] == address(0), "Dlp: already set");
    address dlpToken = dlpTokenFab.createDlpToken("DLP Token", "DLP");
    dlpTokens[pool] = dlpToken;
    emit SetSwapPool(pool, dlpToken);
  }

  function setNftMgr(address _nftMgr) external onlyOwner {
    address old = address(nft);
    nft = ISwapNFT(_nftMgr);
    emit SetSwapNFT(old, _nftMgr);
  }

  function setDuration(uint _duration) external onlyOwner {
    DURATION = _duration;
  }

  function setDlpTokenImpl(address _dlpTokenImpl) external onlyOwner {
    dlpTokenFab.setDlpTokenImpl(_dlpTokenImpl);
    emit SetDlpTokenImpl(address(dlpTokenFab.dlpTokenImpl()), _dlpTokenImpl);
  }

  function setRewardsController(address _rewardsCtrler) external onlyOwner {
    dlpTokenFab.setRewardsCtrler(_rewardsCtrler);
    emit SetRewardsController(address(dlpTokenFab.rewardsCtrler()), _rewardsCtrler);
  }

  function lockLiquidity(address user, address pool, uint liquidity, uint tokenId) external onlyZap {
    _lockLiquidity(user, pool, liquidity, tokenId);
  }

  function _lockLiquidity(address user, address pool, uint liquidity, uint tokenId)
    internal
    onlyZap
  {
    require(liquidity > 0, "Dlp: zero liquidity");
    require(nft.ownerOf(tokenId) == msg.sender, "Dlp: not owner");
    require(dlpParams[tokenId].user == address(0), "Dlp: already locked");

    dlpParams[tokenId] = DlpParams(user, pool, liquidity, block.timestamp + DURATION);
    address dlpToken = dlpTokens[pool];
    DlpToken(dlpToken).mint(user, liquidity);

    nft.safeTransferFrom(msg.sender, address(this), tokenId);
    emit DlpLocked(user, pool, tokenId, liquidity);
  }

  /**
   * @notice lock liquidity
   * @param pool which pool that the liquidity is belong to
   * @param liquidity amount
   * @param tokenId  nft token id
   */
  function lockLiquidity(address pool, uint liquidity, uint tokenId) external {
    address user = msg.sender;
    _lockLiquidity(user, pool, liquidity, tokenId);
  }

  /**
   * @notice unlock liquidity
   * @param tokenId  nft token id
   */
  function unlockLiquidity(uint tokenId, address recipient) external {
    DlpParams memory params = dlpParams[tokenId];
    require(params.user == msg.sender, "Dlp: not owner");
    require(block.timestamp > params.end, "Dlp: not expired");
    address dlpToken = dlpTokens[params.pool];
    require(dlpToken != address(0), "Dlp: not locked");
    DlpToken(dlpToken).burn(msg.sender, params.liquidity);
    delete dlpParams[tokenId];
    nft.safeTransferFrom(address(this), recipient, tokenId);
    emit DlpUnlocked(msg.sender, params.pool, tokenId, params.liquidity);
  }
}
