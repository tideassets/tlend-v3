// SPDX-License-Identifier: MIT
// Copyright (C) 2023
// stake.sol : lock liquidity and redeem dlp token
//

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@aave/periphery-v3/contracts/rewards/interfaces/IRewardsController.sol";
import "./dlp.sol";

contract DlpStaker is Ownable {
  address public zap;
  address public rewardsCtrler;

  // tokenId => DlpParams
  mapping(uint => DlpParams) public dlpParams;
  // pool => DlpToken
  mapping(address => address) public dlpTokens;

  INFTMgr public nftMgr;

  struct DlpParams {
    address user;
    address pool;
    uint liquidity;
    uint start;
    uint duration;
  }

  modifier onlyZap() {
    require(msg.sender == zap, "Dlp: not zap");
    _;
  }

  constructor(
    address _nftMgr,
    address _zap,
    address _rewardsCtrler
  ) Ownable(msg.sender) {
    nftMgr = INFTMgr(_nftMgr);
    zap = _zap;
    rewardsCtrler = _rewardsCtrler;
  }

  event DlpLocked(address indexed pool, uint liquidity, uint start);

  /**
   * @notice lock liquidity
   * @param pool which pool that the liquidity is belong to
   * @param liquidity amount
   * @param tokenId  nft token id
   * @param duration  lock duration
   */
  function lockLiquidity(
    address user,
    address pool,
    uint liquidity,
    uint tokenId,
    uint duration
  ) external {
    require(msg.sender == zap || msg.sender == user, "Dlp: not zap or user");
    require(dlpParams[tokenId].user == address(0), "Dlp: already locked");
    dlpParams[tokenId] = DlpParams(
      user,
      pool,
      liquidity,
      block.timestamp,
      duration
    );
    address dlpToken = dlpTokens[pool];
    if (dlpToken == address(0)) {
      dlpToken = address(new DlpToken("tLend DLP", "DLP", rewardsCtrler, pool));
      dlpTokens[pool] = dlpToken;
    }
    DlpToken(dlpToken).mint(user, liquidity);

    nftMgr.safeTransferFrom(msg.sender, address(this), tokenId);
    emit DlpLocked(pool, liquidity, block.timestamp);
  }

  /**
   * @notice unlock liquidity
   * @param tokenId  nft token id
   */
  function unlockLiquidity(uint tokenId) external {
    DlpParams memory params = dlpParams[tokenId];
    require(params.user == msg.sender, "Dlp: not owner");
    require(
      block.timestamp - params.start > params.duration,
      "Dlp: not expired"
    );
    delete dlpParams[tokenId];
    nftMgr.safeTransferFrom(address(this), msg.sender, tokenId);
  }
}
