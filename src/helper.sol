// SPDX-License-Identifier: MIT
// Copyright (C) 2023
// helper.sol : transfer helper methods
//

// helper methods from uniswap, for sending ETH that do not consistently return true/false
// we modified the original code
library TransferHelper {
	error ETHTransferFailed();

	/**
	 * @notice Transfer ETH
	 * @param to address
	 * @param value ETH amount
	 */
	function safeTransferETH(address to, uint256 value) internal {
		(bool success, ) = to.call{value: value}(new bytes(0));
		if (!success) revert ETHTransferFailed();
	}
}