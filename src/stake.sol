// SPDX-License-Identifier: MIT
// Copyright (C) 2023
// stake.sol : lock liquidity and redeem dlp token
//
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {DlpToken, DlpTokenFab} from "./dlp.sol";
import {ISwapNFT} from "./interface/swapNFT.sol";

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

  function initialize(address _nftMgr, address _zap, address _fab) public initializer {
    __Ownable_init(msg.sender);
    nft = ISwapNFT(_nftMgr);
    zap = _zap;
    dlpTokenFab = DlpTokenFab(_fab);
  }

  event DlpLocked(address indexed pool, uint liquidity, uint start);

  function setZap(address _zap) external onlyOwner {
    zap = _zap;
  }

  function setSwapPool(address pool) external onlyOwner {
    require(dlpTokens[pool] == address(0), "Dlp: already set");
    dlpTokens[pool] = dlpTokenFab.createDlpToken("DLP token", "DLP");
  }

  function setNftMgr(address _nftMgr) external onlyOwner {
    nft = ISwapNFT(_nftMgr);
  }

  function setDuration(uint _duration) external onlyOwner {
    DURATION = _duration;
  }

  function setDlpTokenImpl(address _dlpTokenImpl) external onlyOwner {
    dlpTokenFab.setDlpTokenImpl(_dlpTokenImpl);
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
    emit DlpLocked(pool, liquidity, block.timestamp);
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
  }
}
