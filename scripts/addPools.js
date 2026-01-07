const { ethers } = require("hardhat");
const hre = require("hardhat");
const cfg = require("../config");

async function main() {
  const factory = "0x1F98431c8aD98523631AE4a59f267346ea31F984"; // Uniswap V3 factory on Arbitrum
  const initCodeHash = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54"; // Uniswap V3 pool init code hash

  const sxau = "0x9D5f8C42f21d0234EfF8274dE832C6E123C2b46A";
  const usdc = "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8";
  const weth = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";

  // Function to compute pool address
  function computePoolAddress(tokenA, tokenB, fee) {
    const [token0, token1] = tokenA.toLowerCase() < tokenB.toLowerCase() ? [tokenA, tokenB] : [tokenB, tokenA];
    const salt = ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(["address", "address", "uint24"], [token0, token1, fee]));
    const poolAddress = ethers.utils.getCreate2Address(factory, salt, initCodeHash);
    return poolAddress;
  }

  // SXAU/USDC 0.05%
  const sxauUsdcPool = computePoolAddress(sxau, usdc, 500);
  console.log("SXAU/USDC 0.05% pool:", sxauUsdcPool);

  // SXAU/WETH 0.3%
  const sxauWethPool = computePoolAddress(sxau, weth, 3000);
  console.log("SXAU/WETH 0.3% pool:", sxauWethPool);

  // SXAU/WETH 0.05%
  const sxauWethPool005 = computePoolAddress(sxau, weth, 500);
  console.log("SXAU/WETH 0.05% pool:", sxauWethPool005);

  const c = await hre.ethers.getContractAt("ArbEmpireSkewDex", process.env.CONTRACT);
  for (const p of Object.values(cfg.pools)) {
    await (await c.addPool(p)).wait();
    console.log("Added", p);
  }
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});