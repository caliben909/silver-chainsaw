const { ethers } = require('ethers');

// Configuration
const ARBITRUM_RPC = process.env.ARBITRUM_RPC || 'https://rpc.ankr.com/arbitrum';
const OPTIMISM_RPC = process.env.OPTIMISM_RPC || 'https://rpc.ankr.com/optimism';
const BASE_RPC = process.env.BASE_RPC || 'https://rpc.ankr.com/base';
const BSC_RPC = process.env.BSC_RPC || 'https://rpc.ankr.com/bsc';

const PRIVATE_KEY = process.env.PRIVATE_KEY;
if (!PRIVATE_KEY) throw new Error('PRIVATE_KEY not set');

const DISTRIBUTOR_ADDRESS = '0xYourMCPDistributorAddress'; // Replace with deployed address

// 10 pre-set wallets for profit distribution
const wallets = [
    '0x742d35Cc6634C0532925a3b844Bc454e4438f44e',
    '0x742d35Cc6634C0532925a3b844Bc454e4438f44f',
    '0x742d35Cc6634C0532925a3b844Bc454e4438f44g',
    '0x742d35Cc6634C0532925a3b844Bc454e4438f44h',
    '0x742d35Cc6634C0532925a3b844Bc454e4438f44i',
    '0x742d35Cc6634C0532925a3b844Bc454e4438f44j',
    '0x742d35Cc6634C0532925a3b844Bc454e4438f44k',
    '0x742d35Cc6634C0532925a3b844Bc454e4438f44l',
    '0x742d35Cc6634C0532925a3b844Bc454e4438f44m',
    '0x742d35Cc6634C0532925a3b844Bc454e4438f44n'
];

// Contract ABI
const DISTRIBUTOR_ABI = [
    'function distributeProfits() external',
    'function rescueToken(address token, uint256 amount) external',
    'function setWallets(address[10] calldata _wallets) external',
    'event ProfitsDistributed(uint256 totalAmount, uint256 gasAmount, uint256 distributedAmount)'
];

// ERC20 ABI for balance checks
const ERC20_ABI = [
    'function balanceOf(address account) view returns (uint256)',
    'function symbol() view returns (string)'
];

// Providers
const arbitrumProvider = new ethers.providers.JsonRpcProvider(ARBITRUM_RPC);
const optimismProvider = new ethers.providers.JsonRpcProvider(OPTIMISM_RPC);
const baseProvider = new ethers.providers.JsonRpcProvider(BASE_RPC);
const bscProvider = new ethers.providers.JsonRpcProvider(BSC_RPC);

// Wallet
const wallet = new ethers.Wallet(PRIVATE_KEY, arbitrumProvider);
const distributorContract = new ethers.Contract(DISTRIBUTOR_ADDRESS, DISTRIBUTOR_ABI, wallet);

// Token addresses for balance checks
const WETH_OP = '0x4200000000000000000000000000000000000006'; // WETH on Optimism
const WETH_BASE = '0x4200000000000000000000000000000000000006'; // WETH on Base
const BNB_BSC = '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c'; // WBNB on BSC

async function checkBalances() {
    console.log('🔍 Checking wallet balances across chains...\n');

    for (let i = 0; i < wallets.length; i++) {
        const walletAddr = wallets[i];
        console.log(`Wallet ${i + 1}: ${walletAddr}`);

        try {
            // Optimism WETH
            const wethOpContract = new ethers.Contract(WETH_OP, ERC20_ABI, optimismProvider);
            const opBalance = await wethOpContract.balanceOf(walletAddr);
            console.log(`  OP WETH: ${ethers.utils.formatEther(opBalance)} ETH`);
        } catch (error) {
            console.log(`  OP WETH: Error - ${error.message}`);
        }

        try {
            // Base WETH
            const wethBaseContract = new ethers.Contract(WETH_BASE, ERC20_ABI, baseProvider);
            const baseBalance = await wethBaseContract.balanceOf(walletAddr);
            console.log(`  Base WETH: ${ethers.utils.formatEther(baseBalance)} ETH`);
        } catch (error) {
            console.log(`  Base WETH: Error - ${error.message}`);
        }

        try {
            // BSC BNB
            const bnbContract = new ethers.Contract(BNB_BSC, ERC20_ABI, bscProvider);
            const bscBalance = await bnbContract.balanceOf(walletAddr);
            console.log(`  BSC BNB: ${ethers.utils.formatEther(bscBalance)} BNB`);
        } catch (error) {
            console.log(`  BSC BNB: Error - ${error.message}`);
        }

        console.log('');
    }
}

async function monitorAndDistribute() {
    console.log('🚀 MCP Profit Distribution Engine Started');
    console.log('📍 Monitoring Arbitrum distributor for profits...\n');

    // Set wallets on contract (only once)
    try {
        console.log('Setting wallets on contract...');
        const tx = await distributorContract.setWallets(wallets);
        await tx.wait();
        console.log('✅ Wallets set successfully\n');
    } catch (error) {
        console.log('Wallets already set or error:', error.message, '\n');
    }

    while (true) {
        try {
            const balance = await arbitrumProvider.getBalance(DISTRIBUTOR_ADDRESS);
            const balanceEth = ethers.utils.formatEther(balance);

            console.log(`💰 Distributor Balance: ${balanceEth} ETH`);

            if (parseFloat(balanceEth) > 0.01) { // Minimum threshold
                console.log('🎯 Profits detected! Initiating distribution...\n');

                // Call distributeProfits
                const tx = await distributorContract.distributeProfits();
                console.log(`📤 Distribution TX: ${tx.hash}`);
                await tx.wait();
                console.log('✅ Distribution completed!\n');

                // Wait for cross-chain propagation
                console.log('⏳ Waiting 5 minutes for cross-chain confirmations...');
                await new Promise(resolve => setTimeout(resolve, 5 * 60 * 1000));

                // Check balances
                await checkBalances();

                console.log('🎉 Distribution cycle complete!\n');
            } else {
                console.log('😴 No profits to distribute. Waiting...\n');
            }

        } catch (error) {
            console.log('❌ Error in distribution cycle:', error.message);
            if (error.message.includes('insufficient funds')) {
                console.log('💸 Insufficient gas funds. Sending rescue...');
                try {
                    const rescueTx = await distributorContract.rescueToken(
                        ethers.constants.AddressZero,
                        ethers.utils.parseEther('0.1')
                    );
                    await rescueTx.wait();
                    console.log('✅ Gas rescued');
                } catch (rescueError) {
                    console.log('❌ Rescue failed:', rescueError.message);
                }
            }
        }

        // Wait 30 seconds before next check
        await new Promise(resolve => setTimeout(resolve, 30 * 1000));
    }
}

// Handle shutdown gracefully
process.on('SIGINT', () => {
    console.log('\n🛑 Shutting down MCP Distributor...');
    process.exit(0);
});

// Start the engine
monitorAndDistribute().catch(console.error);