// SPDX-License-Identifier: MIT
// Copyright (C) 2023
// dlp.sol : lock liquidity and redeem liquidity
//

pragma solidity ^0.8.20;

import {IScaledBalanceToken} from "@aave/core-v3/contracts/interfaces/IScaledBalanceToken.sol";
import "@aave/periphery-v3/contracts/rewards/interfaces/IRewardsController.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interface/nft.sol";

contract DlpToken is ERC20, Ownable, IScaledBalanceToken {
  address public pool;
  address public rewardsCtrler;

  constructor(
    string memory name_,
    string memory symbol_,
    address rewardsCtrler_,
    address pool_
  ) ERC20(name_, symbol_) Ownable(msg.sender) {
    pool = pool_;
    rewardsCtrler = rewardsCtrler_;
  }

  function mint(address usr, uint amount) external onlyOwner {
    _mint(usr, amount);
    IRewardsController(rewardsCtrler).handleAction(usr, balanceOf(usr), totalSupply());
  }

  function burn(address usr, uint amount) external onlyOwner {
    _burn(usr, amount);
    IRewardsController(rewardsCtrler).handleAction(usr, balanceOf(usr), totalSupply());
  }

  /**
   * @notice Returns the scaled balance of the user.
   * @dev The scaled balance is the sum of all the updated stored balance divided by the reserve's liquidity index
   * at the moment of the update
   * @param user The user whose balance is calculated
   * @return The scaled balance of the user
   */
  function scaledBalanceOf(address user) external view returns (uint256) {
    return balanceOf(user);
  }

  /**
   * @notice Returns the scaled balance of the user and the scaled total supply.
   * @param user The address of the user
   * @return The scaled balance of the user
   * @return The scaled total supply
   */
  function getScaledUserBalanceAndSupply(address user) external view returns (uint256, uint256) {
    return (balanceOf(user), totalSupply());
  }

  /**
   * @notice Returns the scaled total supply of the scaled balance token. Represents sum(debt/index)
   * @return The scaled total supply
   */
  function scaledTotalSupply() external view returns (uint256) {
    return totalSupply();
  }

  /**
   * @notice Returns last index interest was accrued to the user's balance
   * @return The last index interest was accrued to the user's balance, expressed in ray
   */
  function getPreviousIndex(address) external pure returns (uint256) {
    return 0;
  }
}
