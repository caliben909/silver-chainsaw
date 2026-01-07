/* ------------------------------------------------------------------
   Flashbots-ready atomic multicall executor
   - private mempool only (no public broadcast)
   - 20 % gas buffer + 1 % priority tip cap
   - returns full revert reason if any call fails
------------------------------------------------------------------ */
require("dotenv").config();
const { ethers } = require("ethers");
const { FlashbotsBundleProvider } = require("@flashbots/ethers-provider-bundle");

const MULTICALL3 = "0xcA11bde05977b3631167028862bE2a173976CA11";
const multicallAbi = [
  "function aggregate((address target,bytes callData)[] calls) payable returns (uint256 blockNumber, bytes[] returnData)",
  "function getBaseFee() view returns (uint256)"
];

/**
 * Executes an atomic multicall **via Flashbots private mempool**
 * @param {Array<{target:string, callData:string}>} calls
 * @param {ethers.Wallet} wallet  – must be same instance keeper uses
 * @param {FlashbotsBundleProvider} fbProvider – obtained from keeper init
 * @param {number} targetBlock – block number to land bundle
 * @returns {Promise<{success:bool, txHash?:string, error?:string}>}
 */
async function executeAtomicMulticall(calls, wallet, fbProvider, targetBlock) {
  try {
    if (!Array.isArray(calls) || calls.length === 0)
      throw new Error("Empty calls array");

    const provider = wallet.provider;
    const multicall = new ethers.Contract(MULTICALL3, multicallAbi, provider);

    // ---------- gas estimation ----------
    const gasEstimate = await multicall.estimateGas.aggregate(calls);
    const gasLimit = gasEstimate.mul(120).div(100); // 20 % buffer

    // ---------- fee cap (Arbitrum cheap-l2 safe) ----------
    const base = await provider.getGasPrice();
    const maxFee = base.mul(110).div(100); // never > 10 % above base
    const maxPriority = ethers.utils.parseUnits("0.01", "gwei"); // 0.01 gwei tip

    // ---------- build tx ----------
    const tx = await multicall.populateTransaction.aggregate(calls, {
      gasLimit,
      maxFeePerGas: maxFee,
      maxPriorityFeePerGas: maxPriority,
      type: 2
    });

    // ---------- flashbots bundle ----------
    const bundle = await fbProvider.sendBundle([{ transaction: tx, signer: wallet }], targetBlock);

    // ---------- wait & return ----------
    const wait = await bundle.wait();
    if (wait === 0) return { success: true, txHash: bundle.bundleHash };
    throw new Error("Bundle rejected / reverted");
  } catch (err) {
    console.error("Multicall failed:", err.message);
    return { success: false, error: err.message };
  }
}

module.exports = { executeAtomicMulticall };