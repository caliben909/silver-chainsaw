// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }
    function mint(MintParams calldata params) external returns (uint256, uint128, uint256, uint256);
    function burn(uint256 tokenId) external returns (uint256, uint256);
}