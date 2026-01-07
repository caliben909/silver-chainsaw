const hre = require("hardhat");
const cfg = require("../config");
async function main() {
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