// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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

contract SkimRouter is Ownable {
    using SafeERC20 for IERC20;

    // Uniswap V3 Router on Arbitrum (Jan 2026)
    ISwapRouter public constant OFFICIAL_ROUTER = ISwapRouter(0x3FC91a3AfD70395CD496e5b6F698eBf5e87d0794);

    address public treasury;
    uint256 public devFeeBP = 5; // 0.05%

    constructor(address _treasury) Ownable(msg.sender) {
        treasury = _treasury;
    }

    function swapExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 poolFee,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address recipient
    ) external returns (uint256 amountOut) {
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        uint256 feeAmount = amountIn * devFeeBP / 10000;
        if (feeAmount > 0) {
            IERC20(tokenIn).safeTransfer(treasury, feeAmount);
        }

        IERC20(tokenIn).approve(address(OFFICIAL_ROUTER), amountIn - feeAmount);

        amountOut = OFFICIAL_ROUTER.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: poolFee,
                recipient: recipient,
                deadline: block.timestamp + 300,
                amountIn: amountIn - feeAmount,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0
            })
        );
    }

    function setDevFee(uint256 newFeeBP) external onlyOwner {
        require(newFeeBP <= 20, "max 0.20%");
        devFeeBP = newFeeBP;
    }

    function rescue(address token) external onlyOwner {
        IERC20(token).safeTransfer(owner(), IERC20(token).balanceOf(address(this)));
    }

    receive() external payable {}
}