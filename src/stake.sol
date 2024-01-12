// SPDX-License-Identifier: MIT
// Copyright (C) 2023
// stake.sol : lock liquidity and redeem dlp token
//
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {TransparentUpgradeableProxy} from
  "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {
  IRewardsController,
  RewardsDataTypes,
  IEACAggregatorProxy,
  ITransferStrategyBase
} from "@aave/periphery-v3/contracts/rewards/interfaces/IRewardsController.sol";
import "./dlp.sol";

contract DlpStaker is OwnableUpgradeable {
  uint public constant DURATION = 30 days;
  address public zap;
  DlpTokenFab public dlpTokenFab;

  // tokenId => DlpParams
  mapping(uint => DlpParams) public dlpParams;
  // pool => DlpToken
  mapping(address => address) public dlpTokens;
  // pool => reward data input
  mapping(address => RewardsDataTypes.RewardsConfigInput[]) public rewardDataInputs;

  ISwapNFT public nft;
  IRewardsController public rewardsCtrler;

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

  function initialize(address _nftMgr, address _zap, address _rewardsCtrler) public initializer {
    __Ownable_init(msg.sender);
    nft = ISwapNFT(_nftMgr);
    zap = _zap;
    rewardsCtrler = IRewardsController(_rewardsCtrler);
    dlpTokenFab = new DlpTokenFab(_rewardsCtrler, address(new DlpToken()));
  }

  event DlpLocked(address indexed pool, uint liquidity, uint start);

  function setRewardsCtrler(address _rewardsCtrler) external onlyOwner {
    dlpTokenFab.setRewardsCtrler(_rewardsCtrler);
  }

  function setDlpTokenImpl(address _dlpTokenImpl) external onlyOwner {
    dlpTokenFab.setDlpTokenImpl(_dlpTokenImpl);
  }

  function setRewardConfig(address pool, RewardsDataTypes.RewardsConfigInput[] memory inputs)
    public
    onlyOwner
  {
    address asset = dlpTokens[pool];
    if (asset != address(0)) {
      delete rewardDataInputs[pool];
    }
    RewardsDataTypes.RewardsConfigInput[] storage _inputs = rewardDataInputs[pool];
    for (uint i = 0; i < inputs.length; i++) {
      inputs[i].asset = asset;
      _inputs.push(inputs[i]);
    }
    if (asset == address(0)) {
      return;
    }
    rewardsCtrler.configureAssets(_inputs);
  }

  /**
   * @notice lock liquidity
   * @param pool which pool that the liquidity is belong to
   * @param liquidity amount
   * @param tokenId  nft token id
   */
  function lockLiquidity(address user, address pool, uint liquidity, uint tokenId) external {
    require(msg.sender == zap || msg.sender == user, "Dlp: not zap or user");
    require(dlpParams[tokenId].user == address(0), "Dlp: already locked");
    dlpParams[tokenId] = DlpParams(user, pool, liquidity, block.timestamp, DURATION);
    address dlpToken = dlpTokens[pool];
    if (dlpToken == address(0)) {
      dlpToken = dlpTokenFab.createDlpToken("DLP", "DLP");
      dlpTokens[pool] = dlpToken;
      RewardsDataTypes.RewardsConfigInput[] storage _inputs = rewardDataInputs[pool];
      for (uint i = 0; i < _inputs.length; i++) {
        _inputs[i].asset = dlpToken;
      }
      setRewardConfig(pool, _inputs);
    }
    DlpToken(dlpToken).mint(user, liquidity);

    nft.safeTransferFrom(msg.sender, address(this), tokenId);
    emit DlpLocked(pool, liquidity, block.timestamp);
  }

  /**
   * @notice unlock liquidity
   * @param tokenId  nft token id
   */
  function unlockLiquidity(uint tokenId, address recipient) external {
    DlpParams memory params = dlpParams[tokenId];
    require(params.user == msg.sender, "Dlp: not owner");
    require(block.timestamp - params.start > params.duration, "Dlp: not expired");
    address dlpToken = dlpTokens[params.pool];
    require(dlpToken != address(0), "Dlp: not locked");
    DlpToken(dlpToken).burn(msg.sender, params.liquidity);
    delete dlpParams[tokenId];
    nft.safeTransferFrom(address(this), recipient, tokenId);
  }
}
