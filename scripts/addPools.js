require("dotenv").config();
const { ethers } = require("hardhat");
const cfg = require("../config");

const UNI_FACTORY   = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
const POOL_INIT     = "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54";
const SXAU          = "0x9D5f8C42F21d0234eFF8274de832C6E123c2B46a";
const USDC          = "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8";
const WETH          = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";

/* ----------------------------------------------------------
   Helpers
---------------------------------------------------------- */
function computePoolAddress(tokenA, tokenB, fee) {
  const [token0, token1] = tokenA.toLowerCase() < tokenB.toLowerCase() ? [tokenA, tokenB] : [tokenB, tokenA];
  const salt = ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(["address", "address", "uint24"], [token0, token1, fee])
  );
  return ethers.utils.getCreate2Address(UNI_FACTORY, salt, POOL_INIT);
}

async function poolExists(address) {
  const code = await hre.ethers.provider.getCode(address);
  return code !== "0x";
}

/* ----------------------------------------------------------
   Main
---------------------------------------------------------- */
async function main() {
  const contract = await hre.ethers.getContractAt("ArbEmpireSkewDex", process.env.CONTRACT);

  // 1. ----- compute & add missing SXAU pools -----
  const sxauPools = [
    { t0: SXAU,  t1: USDC, fee: 500,  name: "SXAU/USDC 0.05%" },
    { t0: SXAU,  t1: WETH, fee: 3000, name: "SXAU/WETH 0.3%"  },
    { t0: SXAU,  t1: WETH, fee: 500,  name: "SXAU/WETH 0.05%" },
  ];

  const toAdd = [];
  for (const p of sxauPools) {
    const addr = computePoolAddress(p.t0, p.t1, p.fee);
    if (!(await poolExists(addr))) {
      console.log(`⚠️  Pool ${p.name} does not exist on-chain – skipping`);
      continue;
    }
    toAdd.push(addr);
    console.log(`✅ ${p.name}  ${addr}`);
  }

  // 2. ----- add all pools from config.js -----
  for (const [key, addr] of Object.entries(cfg.pools)) {
    if (await poolExists(addr)) {
      toAdd.push(addr);
      console.log(`✅ ${key}  ${addr}`);
    } else {
      console.log(`⚠️  Config pool ${key}  ${addr}  not deployed – skipping`);
    }
  }

  // 3. ----- batch-add via multicall3 to save gas -----
  const iface = contract.interface;
  const calls = toAdd.map(a => ({
    target: contract.address,
    callData: iface.encodeFunctionData("addPool", [a])
  }));

  const multicall = await hre.ethers.getContractAt(
    ["function aggregate((address,bytes)[] calls) payable returns (uint256,bytes[])"],
    "0xcA11bde05977b3631167028862bE2a173976CA11"
  );

  const tx = await multicall.aggregate(calls, { gasLimit: 1_500_000 });
  const receipt = await tx.wait();

  console.log(`🎉  Added ${toAdd.length} pools in tx ${receipt.transactionHash}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});