// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.26;

/**
 * @title Uniswap V3 Swap Callback Interface
 * @notice Contracts implementing this must verify the caller is a trusted V3 pool.
 */
interface IUniswapV3SwapCallback {
    /// @notice Called to `msg.sender` after executing a swap via IUniswapV3Pool#swap.
    /// @param amount0Delta Amount of token0 sent to the caller (negative = pool owes caller)
    /// @param amount1Delta Amount of token1 sent to the caller (negative = pool owes caller)
    /// @param data Any data passed through by the caller via the swap function
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}