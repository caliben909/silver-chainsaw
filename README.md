# DeFi Empire Bot

This is an advanced DeFi arbitrage bot designed for the Arbitrum network. It performs various arbitrage strategies including triangular and quad arbitrages, flash loans, and more, utilizing multiple tokens and protocols.

## Features

- Flash loan arbitrage using Aave
- Triangular and quad arbitrage cycles
- Support for multiple tokens on Arbitrum
- Dynamic token fetching
- Pool checker for arbitrage opportunities
- Automated AI-driven trading

## Installation

1. **Clone the repository:**
   ```
   git clone https://github.com/caliben909/super-duper-lamp.git
   cd super-duper-lamp
   ```

2. **Install dependencies:**
   ```
   npm install
   ```

3. **Set up environment variables:**
   - Copy `.env` and update it with your actual values:
     - `PRIVATE_KEY`: Your Ethereum private key (keep secure)
     - `GODMODE_EMPIRE_ADDRESS`: Address of the deployed GodModeEmpire contract (after deployment)

4. **Compile the contracts:**
   ```
   npx hardhat compile
   ```

5. **Run tests:**
   ```
   npx hardhat test
   ```

6. **Deploy contracts to Arbitrum:**
   - Ensure your .env has a valid PRIVATE_KEY
   - Run:
     ```
     npx hardhat run scripts/deploy-godmode-empire.js --network arbitrum
     ```
   - Note the deployed contract address and update .env if needed

7. **Run the AI bot:**
   ```
   node empire-ai.js
   ```

## Requirements

- Node.js >= 14.0.0
- npm
- An Ethereum wallet with ETH on Arbitrum for gas fees
- Access to Arbitrum network (via RPC or WebSocket)

## Contracts

- `GodModeEmpire.sol`: Main arbitrage contract with flash loan strategies
- `SkimRouter.sol`: Swap router with fee mechanism
- `YourDEXArbitrage.sol`: Additional arbitrage contract using Aave flash loans

## Scripts

- `empire-ai.js`: AI script that monitors and executes arbitrage opportunities
- `fetchArbitrumTokens()`: Fetches token list from CoinGecko

## Testing

Run the test suite:
```
npx hardhat test
```

This will list all token addresses and verify contract functionality.

## Disclaimer

This is experimental software. Use at your own risk. Ensure you understand the code and risks involved in DeFi trading.