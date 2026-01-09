// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title MCPDistributor
 * @dev Multi-Chain Profit Distributor for Pure ETH Arbitrage Profits
 * Distributes ETH profits equally across 10 pre-configured wallets
 */
contract MCPDistributor is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // 10 wallets for profit distribution
    address[10] public wallets;

    // Events
    event ProfitsDistributed(uint256 totalAmount, uint256 gasAmount, uint256 distributedAmount);
    event WalletsUpdated(address[10] oldWallets, address[10] newWallets);
    event TokenRescued(address token, uint256 amount, address to);

    // Gas reserve for operations (0.01 ETH)
    uint256 public constant GAS_RESERVE = 0.01 ether;

    constructor() Ownable(msg.sender) {
        // Initialize wallets with BNB addresses (ETH will be bridged to BNB)
        wallets[0] = 0x85c52639d6B2bB4190971BD9321f38A9cF46Ec0d;
        wallets[1] = 0x0515982b44E9DAb9B0F338F67bFa860105Da8119;
        wallets[2] = 0x8f7D06EaD86A33B48779c63c3dC3b9bF606e6803;
        wallets[3] = 0x1Dcffb3484eA494Fc81c1442F00016bAcf5F577D;
        wallets[4] = 0xAa9Da2b1C2D147812fF99Be3a043C0d481d4953a;
        wallets[5] = 0xA6aB3A3CAd0a6B8bc67f0739AFf6De9154112483;
        wallets[6] = 0x319Ae00F27b12cb8e438690fd47E7161b81AE64D;
        wallets[7] = 0x06Fd8A5D09DaFB62840aDCcB41A6899Ca9BEcF21;
        wallets[8] = 0xB64daAC3347d65ff78f12cEF54bb7C7ECf6CE808;
        wallets[9] = 0x4b728c37D6950658AC052AeD86B720fC83c51924;
    }

    /**
     * @dev Set the 10 distribution wallets
     */
    function setWallets(address[10] calldata _wallets) external onlyOwner {
        address[10] memory oldWallets = wallets;
        wallets = _wallets;
        emit WalletsUpdated(oldWallets, wallets);
    }

    /**
     * @dev Distribute all ETH profits equally across the 10 wallets
     * Reserves GAS_RESERVE for future operations
     */
    function distributeProfits() external nonReentrant {
        uint256 balance = address(this).balance;

        require(balance > GAS_RESERVE, "Insufficient balance for distribution");

        uint256 distributableAmount = balance - GAS_RESERVE;
        uint256 amountPerWallet = distributableAmount / 10;

        require(amountPerWallet > 0, "Amount per wallet too small");

        // Distribute to each wallet
        for (uint256 i = 0; i < 10; i++) {
            require(wallets[i] != address(0), "Wallet not set");
            (bool success,) = payable(wallets[i]).call{value: amountPerWallet}("");
            require(success, "Transfer failed");
        }

        emit ProfitsDistributed(balance, GAS_RESERVE, distributableAmount);
    }

    /**
     * @dev Rescue tokens stuck in contract (emergency function)
     */
    function rescueToken(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            // ETH rescue
            (bool success,) = payable(owner()).call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            // ERC20 rescue
            IERC20(token).safeTransfer(owner(), amount);
        }
        emit TokenRescued(token, amount, owner());
    }

    /**
     * @dev Get current wallets array
     */
    function getWallets() external view returns (address[10] memory) {
        return wallets;
    }

    /**
     * @dev Receive ETH profits from arbitrage contracts
     */
    receive() external payable {}
}