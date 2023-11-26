// SPDX-License-Identifier: MIT
// Copyright (C) 2023
// dlp.sol : lock liquidity and redeem liquidity
//

pragma solidity ^0.8.20;

import "./interface/nft.sol";

contract Dlp {
    struct DlpParams {
        address pool;
        uint liquidity;
        uint tokenId;
        uint start;
        uint duration;
    }

    // user => DlpParams
    mapping(address => DlpParams) public dlpParams;

    INFTMgr public nftMgr;

    constructor(address _nftMgr) {
        nftMgr = INFTMgr(_nftMgr);
    }

    event DlpLocked(address indexed pool, uint liquidity, uint start);

    /**
     * @notice lock liquidity
     * @param usr  address
     * @param pool which pool that the liquidity is belong to
     * @param liquidity amount
     * @param tokenId  nft token id
     * @param duration  lock duration
     */
    function lockLiquidity(
        address usr,
        address pool,
        uint liquidity,
        uint tokenId,
        uint duration
    ) external {
        require(dlpParams[usr].pool == address(0), "Dlp: already locked");
        dlpParams[usr] = DlpParams(
            pool,
            liquidity,
            tokenId,
            block.timestamp,
            duration
        );
        nftMgr.safeTransferFrom(usr, address(this), tokenId);
        emit DlpLocked(pool, liquidity, block.timestamp);
    }

    /**
     * @notice unlock liquidity
     * @param usr address
     */
    function unlockLiquidity(address usr) external {
        DlpParams memory params = dlpParams[usr];
        require(params.pool != address(0), "Dlp: not locked");
        require(
            block.timestamp - params.start > params.duration,
            "Dlp: not expired"
        );
        delete dlpParams[usr];
        nftMgr.safeTransferFrom(address(this), usr, params.tokenId);
    }
}
