// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol";

interface IStargateRouter {
    function swap(
        uint16 _dstChainId,uint256 _srcPoolId,uint256 _dstPoolId,address payable _refundAddress,
        uint256 _amountLD,uint256 _minAmountLD,lzTxObj memory _lzTxParams,bytes calldata _to,bytes calldata _payload
    ) external payable;
    function quoteLayerZeroFee(
        uint16 _dstChainId,uint8 _functionType,bytes calldata _toAddress,bytes calldata _transferAndCallPayload,lzTxObj memory _lzTxParams
    ) external view returns (uint256 nativeFee,uint256 zroFee);
}

struct lzTxObj {
    uint256 dstGasForCall;
    uint256 dstNativeAmount;
    bytes dstNativeAddr;
}

interface IMCPDistributor {
    function getWallets() external view returns (address[10] memory);
}

interface IPositionManager {
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

interface IQuoter {
    function quoteExactInputSingle(address tokenIn, address tokenOut, uint24 fee, uint256 amountIn, uint160 sqrtPriceLimitX96) external returns (uint256 amountOut);
}

interface ISkimRouter {
    function swapExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 poolFee,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address recipient
    ) external returns (uint256 amountOut);
}

interface IAavePool {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface IFlashLoanReceiver {
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}