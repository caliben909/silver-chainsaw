// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

contract YourDEXArbitrage {
    using SafeERC20 for IERC20;

    IPool constant pool = IPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD); // Aave V3 on Arbitrum
    ISwapRouter constant router = ISwapRouter(0x3FC91a3AfD70395CD496e5b6F698eBf5e87d0794); // Uniswap V3 on Arbitrum

    address constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5b0f;

    function executeFlashLoan(address token, uint256 amount) external {
        pool.flashLoanSimple(address(this), token, amount, "", 0);
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        require(msg.sender == address(pool), "Not Aave");

        // Triangular arbitrage: asset -> USDT -> WETH -> asset
        uint256 amountIn = amount / 3;
        _swap(asset, USDT, 100, amountIn);
        _swap(USDT, WETH, 3000, amountIn);
        _swap(WETH, asset, 3000, amountIn);

        // Repay
        uint256 totalRepay = amount + premium;
        require(IERC20(asset).balanceOf(address(this)) >= totalRepay, "Insufficient funds");
        IERC20(asset).safeTransfer(address(pool), totalRepay);

        return true;
    }

    function _swap(address tokenIn, address tokenOut, uint24 fee, uint256 amountIn) internal returns (uint256 amountOut) {
        IERC20(tokenIn).approve(address(router), amountIn);
        amountOut = router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: address(this),
                deadline: block.timestamp + 300,
                amountIn: amountIn,
                amountOutMinimum: 0, // For simplicity, no slippage check
                sqrtPriceLimitX96: 0
            })
        );
    }

    receive() external payable {}
}