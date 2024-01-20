// SPDX-License-Identifier: MIT
// Copyright (C) 2023
// dlp.sol : lock liquidity and redeem liquidity
//
pragma solidity ^0.8.20;

import {IScaledBalanceToken} from "@aave/core-v3/contracts/interfaces/IScaledBalanceToken.sol";
import {ERC20Upgradeable} from
  "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {TransparentUpgradeableProxy} from
  "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IRewardsController} from
  "@aave/periphery-v3/contracts/rewards/interfaces/IRewardsController.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/swapNFT.sol";


contract DlpToken is ERC20Upgradeable, OwnableUpgradeable, IScaledBalanceToken {
  address public rewardsCtrler;

  function initialize(string memory name_, string memory symbol_, address rewardsCtrler_)
    public
    initializer
  {
    __ERC20_init(name_, symbol_);
    __Ownable_init(msg.sender);
    rewardsCtrler = rewardsCtrler_;
  }

  function mint(address usr, uint amount) external onlyOwner {
    _mint(usr, amount);
  }

  function burn(address usr, uint amount) external onlyOwner {
    _burn(usr, amount);
  }

  function _update(address from, address to, uint amount) internal override {
    if (from != address(0)) {
      IRewardsController(rewardsCtrler).handleAction(from, balanceOf(from), totalSupply());
    }
    if (to != address(0)) {
      IRewardsController(rewardsCtrler).handleAction(to, balanceOf(to), totalSupply());
    }

    super._update(from, to, amount);
  }

  /**
   * @notice Returns the scaled balance of the user.
   * @dev The scaled balance is the sum of all the updated stored balance divided by the reserve's liquidity index
   * at the moment of the update
   * @param user The user whose balance is calculated
   * @return The scaled balance of the user
   */
  function scaledBalanceOf(address user) external view returns (uint) {
    return balanceOf(user);
  }

  /**
   * @notice Returns the scaled balance of the user and the scaled total supply.
   * @param user The address of the user
   * @return The scaled balance of the user
   * @return The scaled total supply
   */
  function getScaledUserBalanceAndSupply(address user) external view returns (uint, uint) {
    return (balanceOf(user), totalSupply());
  }

  /**
   * @notice Returns the scaled total supply of the scaled balance token. Represents sum(debt/index)
   * @return The scaled total supply
   */
  function scaledTotalSupply() external view returns (uint) {
    return totalSupply();
  }

  /**
   * @notice Returns last index interest was accrued to the user's balance
   * @return The last index interest was accrued to the user's balance, expressed in ray
   */
  function getPreviousIndex(address) external pure returns (uint) {
    return 0;
  }
}

contract DlpTokenFab is Ownable {
  address public rewardsCtrler;
  address public dlpTokenImpl;

  constructor(address _rewardsCtrler, address _dlpTokenImpl) Ownable(msg.sender) {
    rewardsCtrler = _rewardsCtrler;
    dlpTokenImpl = _dlpTokenImpl;
  }

  function setRewardsCtrler(address _rewardsCtrler) external onlyOwner {
    rewardsCtrler = _rewardsCtrler;
  }

  function setDlpTokenImpl(address _dlpTokenImpl) external onlyOwner {
    dlpTokenImpl = _dlpTokenImpl;
  }

  function createDlpToken(string memory name, string memory symbol) external returns (address) {
    bytes memory data =
      abi.encodeWithSignature("initialize(string,string,address)", name, symbol, rewardsCtrler);

    TransparentUpgradeableProxy proxy =
      new TransparentUpgradeableProxy(dlpTokenImpl, msg.sender, data);

    return address(proxy);
  }
}
