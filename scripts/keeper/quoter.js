const { Contract, ethers } = require("ethers");

const QUOTER = "0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6";
const abi = ["function quoteExactInputSingle(address,address,uint24,uint256,uint160) external view returns (uint256)"];

const meta = require("../../config").meta; // decimals + address map
const fees = require("../../config").fees; // fee tier per pair

async function quoteExactInput(tokenIn, tokenOut, amountHuman, provider) {
  if (!tokenIn || !tokenOut || !amountHuman || !provider) {
    throw new Error("Invalid input parameters");
  }
  const mIn = meta[tokenIn.symbol];
  const mOut = meta[tokenOut.symbol];
  if (!mIn || !mOut) {
    throw new Error("Token metadata not found");
  }
  const amountIn = ethers.utils.parseUnits(amountHuman, mIn.decimals);
  const fee = fees[`${tokenIn.symbol}/${tokenOut.symbol}`] || 3000;
  const quoter = new Contract(QUOTER, abi, provider);
  try {
    const amountOut = await quoter.quoteExactInputSingle(mIn.addr, mOut.addr, fee, amountIn, 0);
    return ethers.utils.formatUnits(amountOut, mOut.decimals);
  } catch (error) {
    throw new Error(`Quoting failed: ${error.message}`);
  }
}

module.exports = { quoteExactInput };