// SPDX-License-Identifier: MIT
// Copyright (C) 2023
// leverater.sol : from radiant leverager, loop deposit and borrow to get more leverage
//
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IPool, DataTypes} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {WETH9} from "@aave/core-v3/contracts/dependencies/weth/WETH9.sol";
import {IAaveOracle} from "@aave/core-v3/contracts/interfaces/IAaveOracle.sol";
import {TransferHelper} from "./helper.sol";

contract Leverager is OwnableUpgradeable {
  using SafeERC20 for IERC20;

  /// @notice margin estimation used for zapping eth to dlp
  uint public constant ZAP_MARGIN_ESTIMATION = 6;

  /// @notice maximum margin allowed to be set by the deployer
  uint public constant MAX_MARGIN = 10;

  /// @notice Ratio Divisor
  uint public constant RATIO_DIVISOR = 10000;

  // Max reasonable fee, 1%
  uint public constant MAX_REASONABLE_FEE = 100;

  /// @notice Mock ETH address
  address public constant API_ETH_MOCK_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  /// @notice LTV Calculation precision
  uint public constant TWO_POW_16 = 2 ** 16;

  /// @notice Interest rate mode
  uint public constant INTEREST_RATE_MODE = 2;

  /// @notice Lending Pool address
  IPool public lendingPool;

  /// @notice EligibilityDataProvider contract address
  // IEligibilityDataProvider public eligibilityDataProvider;

  /// @notice LockZap contract address
  // ILockZap public lockZap;

  /// @notice Wrapped ETH contract address
  WETH9 public weth;

  /// @notice Aave oracle address
  IAaveOracle public aaveOracle;

  /// @notice Fee ratio
  uint public feePercent;

  /// @notice Treasury address
  address public treasury;

  /// @notice ChefIncentivesController contract address
  // IChefIncentivesController public cic;

  /// @notice Emitted when fee ratio is updated
  event FeePercentUpdated(uint indexed _feePercent);

  /// @notice Emitted when treasury is updated
  event TreasuryUpdated(address indexed _treasury);

  error AddressZero();

  error ReceiveNotAllowed();

  error FallbackNotAllowed();

  error InsufficientPermission();

  error EthTransferFailed();

  /// @notice Disallow a loop count of 0
  error InvalidLoopCount();

  /// @notice Emitted when ratio is invalid
  error InvalidRatio();

  /// @notice Thrown when deployer sets the margin too high
  error MarginTooHigh();

  constructor() {
    _disableInitializers();
  }

  /**
   * @notice Initializer
   * @param _lendingPool Address of lending pool.
   * @param _aaveOracle address.
   * @param _weth WETH address.
   * @param _feePercent leveraging fee ratio.
   * @param _treasury address.
   */
  function initialize(
    IPool _lendingPool,
    IAaveOracle _aaveOracle,
    WETH9 _weth,
    uint _feePercent,
    address _treasury
  ) public initializer {
    if (address(_lendingPool) == address(0)) revert AddressZero();
    if (address(_aaveOracle) == address(0)) revert AddressZero();
    if (address(_weth) == address(0)) revert AddressZero();
    if (_treasury == address(0)) revert AddressZero();
    if (_feePercent > MAX_REASONABLE_FEE) revert InvalidRatio();
    __Ownable_init(msg.sender);

    lendingPool = _lendingPool;
    aaveOracle = _aaveOracle;
    weth = _weth;
    feePercent = _feePercent;
    treasury = _treasury;
  }

  /**
   * @dev Only WETH contract is allowed to transfer ETH here. Prevent other addresses to send Ether to this contract.
   */
  receive() external payable {
    if (msg.sender != address(weth)) revert ReceiveNotAllowed();
  }

  /**
   * @dev Revert fallback calls
   */
  fallback() external payable {
    revert FallbackNotAllowed();
  }

  /**
   * @notice Sets fee ratio
   * @param _feePercent fee ratio.
   */
  function setFeePercent(uint _feePercent) external onlyOwner {
    if (_feePercent > MAX_REASONABLE_FEE) revert InvalidRatio();
    feePercent = _feePercent;
    emit FeePercentUpdated(_feePercent);
  }

  /**
   * @notice Sets fee ratio
   * @param _treasury address
   */
  function setTreasury(address _treasury) external onlyOwner {
    if (_treasury == address(0)) revert AddressZero();
    treasury = _treasury;
    emit TreasuryUpdated(_treasury);
  }

  /**
   * @dev Returns the configuration of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The configuration of the reserve
   *
   */
  function getConfiguration(address asset)
    public
    view
    returns (DataTypes.ReserveConfigurationMap memory)
  {
    return lendingPool.getConfiguration(asset);
  }

  /**
   * @dev Returns variable debt token address of asset
   * @param asset The address of the underlying asset of the reserve
   * @return varaiableDebtToken address of the asset
   *
   */
  function getVDebtToken(address asset) external view returns (address) {
    DataTypes.ReserveData memory reserveData = lendingPool.getReserveData(asset);
    return reserveData.variableDebtTokenAddress;
  }

  /**
   * @dev Returns loan to value
   * @param asset The address of the underlying asset of the reserve
   * @return ltv of the asset
   *
   */
  function ltv(address asset) external view returns (uint) {
    DataTypes.ReserveConfigurationMap memory conf = getConfiguration(asset);
    return conf.data % TWO_POW_16;
  }

  function loopWithBorrow(address asset, uint amount, uint borrowRatio, uint loopCount) external {
    _loop(asset, amount, INTEREST_RATE_MODE, borrowRatio, loopCount, true);
  }

  function loopWithDeposit(address asset, uint amount, uint borrowRatio, uint loopCount) external {
    _loop(asset, amount, INTEREST_RATE_MODE, borrowRatio, loopCount, false);
  }

  /**
   * @dev Loop the deposit and borrow of an asset
   * @param asset for loop
   * @param amount for the initial deposit
   * @param interestRateMode stable or variable borrow mode
   * @param borrowRatio Ratio of tokens to borrow
   * @param loopCount Repeat count for loop
   * @param isBorrow true when the loop without deposit tokens
   *
   */
  function _loop(
    address asset,
    uint amount,
    uint interestRateMode,
    uint borrowRatio,
    uint loopCount,
    bool isBorrow
  ) internal {
    if (!(borrowRatio > 0 && borrowRatio <= RATIO_DIVISOR)) revert InvalidRatio();
    if (loopCount == 0) revert InvalidLoopCount();
    uint16 referralCode = 0;
    uint fee;
    if (!isBorrow) {
      IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
      fee = (amount * feePercent) / RATIO_DIVISOR;
      if (fee > 0) {
        IERC20(asset).safeTransfer(treasury, fee);
        amount = amount - fee;
      }
    }
    _approve(asset);

    if (!isBorrow) {
      lendingPool.deposit(asset, amount, msg.sender, referralCode);
    } else {
      amount = (amount * RATIO_DIVISOR) / borrowRatio;
    }

    for (uint i = 0; i < loopCount;) {
      amount = (amount * borrowRatio) / RATIO_DIVISOR;
      lendingPool.borrow(asset, amount, interestRateMode, referralCode, msg.sender);

      fee = (amount * feePercent) / RATIO_DIVISOR;
      if (fee > 0) {
        IERC20(asset).safeTransfer(treasury, fee);
        amount = amount - fee;
      }

      lendingPool.deposit(asset, amount, msg.sender, referralCode);
      unchecked {
        i++;
      }
    }
  }

  /**
   * @dev Loop the deposit and borrow of ETH
   * @param interestRateMode stable or variable borrow mode
   * @param borrowRatio Ratio of tokens to borrow
   * @param loopCount Repeat count for loop
   *
   */
  function loopETH(uint interestRateMode, uint borrowRatio, uint loopCount) external payable {
    if (!(borrowRatio > 0 && borrowRatio <= RATIO_DIVISOR)) revert InvalidRatio();
    if (loopCount == 0) revert InvalidLoopCount();
    uint16 referralCode = 0;
    uint amount = msg.value;
    _approve(address(weth));

    uint fee = (amount * feePercent) / RATIO_DIVISOR;
    if (fee > 0) {
      TransferHelper.safeTransferETH(treasury, fee);
      amount = amount - fee;
    }

    weth.deposit{value: amount}();
    lendingPool.deposit(address(weth), amount, msg.sender, referralCode);

    for (uint i = 0; i < loopCount;) {
      amount = (amount * borrowRatio) / RATIO_DIVISOR;
      lendingPool.borrow(address(weth), amount, interestRateMode, referralCode, msg.sender);

      fee = (amount * feePercent) / RATIO_DIVISOR;
      if (fee > 0) {
        weth.withdraw(fee);
        TransferHelper.safeTransferETH(treasury, fee);
        amount = amount - fee;
      }

      lendingPool.deposit(address(weth), amount, msg.sender, referralCode);
      unchecked {
        i++;
      }
    }
  }

  /**
   * @dev Loop the borrow and deposit of ETH
   * @param interestRateMode stable or variable borrow mode
   * @param amount initial amount to borrow
   * @param borrowRatio Ratio of tokens to borrow
   * @param loopCount Repeat count for loop
   *
   */
  function loopETHFromBorrow(uint interestRateMode, uint amount, uint borrowRatio, uint loopCount)
    external
  {
    if (!(borrowRatio > 0 && borrowRatio <= RATIO_DIVISOR)) revert InvalidRatio();
    if (loopCount == 0) revert InvalidLoopCount();
    uint16 referralCode = 0;
    _approve(address(weth));

    uint fee;

    for (uint i = 0; i < loopCount;) {
      lendingPool.borrow(address(weth), amount, interestRateMode, referralCode, msg.sender);

      fee = (amount * feePercent) / RATIO_DIVISOR;
      if (fee > 0) {
        weth.withdraw(fee);
        TransferHelper.safeTransferETH(treasury, fee);
        amount = amount - fee;
      }

      lendingPool.deposit(address(weth), amount, msg.sender, referralCode);

      amount = (amount * borrowRatio) / RATIO_DIVISOR;
      unchecked {
        i++;
      }
    }
  }

  /**
   * @notice Approves token allowance of `lendingPool` and `treasury`.
   * @param asset underlyig asset
   *
   */
  function _approve(address asset) internal {
    if (IERC20(asset).allowance(address(this), address(lendingPool)) == 0) {
      IERC20(asset).forceApprove(address(lendingPool), type(uint).max);
    }
    if (IERC20(asset).allowance(address(this), address(treasury)) == 0) {
      IERC20(asset).forceApprove(treasury, type(uint).max);
    }
  }
}
