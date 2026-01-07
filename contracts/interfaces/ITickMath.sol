// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ITickMath {
    function getSqrtRatioAtTick(int24 tick) external pure returns (uint160);
    function getTickAtSqrtRatio(uint160 sqrtPriceX96) external pure returns (int24);
}