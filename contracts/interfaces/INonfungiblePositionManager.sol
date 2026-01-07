// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface INonfungiblePositionManager is IERC721 {
    /// @notice Returns the position information associated with a given token ID.
    /// @dev Throws if the token ID is not valid.
    /// @param tokenId The ID of the token that represents the position
    /// @return nonce The nonce for permits
    /// @return operator The address that is approved for spending
    /// @return token0 The address of the token0 for a specific pool
    /// @return token1 The address of the token1 for a specific pool
    /// @return fee The fee associated with the pool
    /// @return tickLower The lower end of the tick range for the position
    /// @return tickUpper The upper end of the tick range for the position
    /// @return liquidity The liquidity of the position
    /// @return feeGrowthInside0LastX128 The fee growth of token0 collected per unit of liquidity for the entire life of the position
    /// @return feeGrowthInside1LastX128 The fee growth of token1 collected per unit of liquidity for the entire life of the position
    /// @return tokensOwed0 The tokens owed to the position owner in token0
    /// @return tokensOwed1 The tokens owed to the position owner in token1
    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

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

    /// @notice Creates a new position wrapped in a NFT
    /// @dev Call this when the pool does exist and is initialized. Note that if the pool is created but not initialized
    /// a method does not exist, i.e. the pool is assumed to be initialized.
    /// @param params The params necessary to mint a position, encoded as `MintParams` in calldata
    /// @return tokenId The ID of the token that represents the minted position
    /// @return liquidity The amount of liquidity for this position
    /// @return amount0 The amount of token0
    /// @return amount1 The amount of token1
    function mint(MintParams calldata params)
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    /// @notice Burns a token ID, which deletes it from the NFT contract. The token must have 0 liquidity and all 0 tokensOwed.
    /// @param tokenId The ID of the token that is being burned
    /// @return amount0 The amount of token0 sent to the owner
    /// @return amount1 The amount of token1 sent to the owner
    function burn(uint256 tokenId) external returns (uint256 amount0, uint256 amount1);

    /// @notice Unwraps WETH9 into native ETH and sends to recipient
    /// @param recipient The address receiving ETH
    /// @param amountMinimum The minimum amount of WETH9 to unwrap
    function unwrapWETH9(uint256 amountMinimum, address recipient) external;

    /// @notice Refund any native ETH balance left
    function refundETH() external payable;
}