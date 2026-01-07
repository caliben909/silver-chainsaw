const ethers = require("ethers");
const { BigNumber } = ethers;
const { Quoter } = require("@uniswap/v3-sdk");
const { Token } = require("@uniswap/sdk-core");
const cfg = require("../../config");
const provider = new ethers.providers.JsonRpcProvider(cfg.rpc.primary);
const QUOTER = "0x61fFE014bA17989E743c5F6cB21bF9697530B21e";

async function getCurrentTick(poolAddress) {
  const poolContract = new ethers.Contract(poolAddress, [
    'function slot0() view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint8 feeProtocol, bool unlocked)'
  ], provider);
  const { tick } = await poolContract.slot0();
  return tick;
}

async function quoteExact0For1(pool, amountIn, tokenIn, tokenOut) {
  const quoterContract = new ethers.Contract(QUOTER, [
    'function quoteExactInputSingle(address tokenIn, address tokenOut, uint24 fee, uint256 amountIn, uint160 sqrtPriceLimitX96) view returns (uint256 amountOut)'
  ], provider);
  const fee = 500; // 0.05 % for USDC/WETH
  const amountOut = await quoterContract.quoteExactInputSingle(tokenIn, tokenOut, fee, amountIn, 0);
  return amountOut;
}

async function quoteExact1For0(pool, amountIn, tokenIn, tokenOut) {
  const quoterContract = new ethers.Contract(QUOTER, [
    'function quoteExactInputSingle(address tokenIn, address tokenOut, uint24 fee, uint256 amountIn, uint160 sqrtPriceLimitX96) view returns (uint256 amountOut)'
  ], provider);
  const fee = 500; // 0.05 % for USDC/WETH
  const amountOut = await quoterContract.quoteExactInputSingle(tokenIn, tokenOut, fee, amountIn, 0);
  return amountOut;
}

async function opportunity(keeper) {
  // 1. find best skew
  const best = await findBestSkew(keeper);
  if (best.profitWei.gt(0)) return best;
  // 2. fallback triangular
  return await findTriangular(keeper);
}

async function findBestSkew(keeper) {
  const USDC = new Token(42161, cfg.tokens.USDC, 6, "USDC", "USD Coin");
  const WETH = new Token(42161, cfg.tokens.WETH, 18, "WETH", "Wrapped Ether");
  const pool = cfg.pools["USDC/WETH"];
  const amountIn = BigNumber.from(50_000 * 1e6); // 50 k USDC
  const tick = await getCurrentTick(pool);
  const tickSpacing = 10; // 0.05 % pool
  const tickLower = Math.floor(tick / tickSpacing) * tickSpacing - tickSpacing;
  const tickUpper = tickLower + 2 * tickSpacing;

  // off-chain replicate of _calcSkewAmounts
  const isToken0 = true; // we borrow USDC (token0)
  const amount0 = amountIn.mul(495).div(1000); // 49.5 %
  const amount1 = amountIn.mul(505).div(1000); // 50.5 % (converted at current price)

  // current price from Quoter
  const price = await quoteExact0For1(pool, ethers.utils.parseUnits("1", 6), cfg.tokens.USDC, cfg.tokens.WETH);
  const amount1Wei = amount1.mul(price).div(1e6);
  // 1. mint NFT with (amount0, amount1Wei)
  // 2. swap amount0 through our tick → receive outWETH
  const outWETH = await quoteExact0For1(pool, amount0, cfg.tokens.USDC, cfg.tokens.WETH);
  // 3. repay flash-swap: amountIn + 0.3 % fee
  const repay = amountIn.mul(1003).div(1000);
  // 4. convert outWETH → USDC
  const backUSDC = await quoteExact1For0(pool, outWETH, cfg.tokens.WETH, cfg.tokens.USDC);
  const profit = backUSDC.sub(repay);
  if (profit.gt(amountIn.mul(30).div(10000))) { // 0.3 %
    return {
      profitWei: profit,
      targetBlock: await provider.getBlockNumber() + 1,
      toTx: () => buildFlashSwapTx(pool, amountIn, isToken0)
    };
  } else {
    return {
      profitWei: BigNumber.from(0),
      targetBlock: await provider.getBlockNumber() + 1,
      toTx: () => null
    };
  }
}

function buildSkewTx(pool, amount, isToken0) {
  const iface = new ethers.utils.Interface([
    "function arbSkew((address,address,uint256,int24,bool,uint160))"
  ]);
  const data = iface.encodeFunctionData("arbSkew", [{
    pool: pool,
    tokenIn: cfg.tokens.USDC,
    amount: amount,
    tickSpacing: 10,
    isToken0: isToken0,
    sqrtPriceLimitX96: 0
  }]);
  return { to: process.env.CONTRACT, data, gasLimit: 350_000 };
}

function buildFlashSwapTx(pool, amount, isToken0) {
  const iface = new ethers.utils.Interface([
    "function flashSwap((address,address,uint256,bool))"
  ]);
  const data = iface.encodeFunctionData("flashSwap", [{
    pool: pool,
    tokenIn: cfg.tokens.USDC,
    amount: amount,
    isToken0: isToken0
  }]);
  return { to: process.env.CONTRACT, data, gasLimit: 350_000 };
}

module.exports = { opportunity };