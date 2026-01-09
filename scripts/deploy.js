const hre = require("hardhat");
async function main() {
  const [owner] = await hre.ethers.getSigners();
  const ArbEmpire = await hre.ethers.getContractFactory("ArbEmpireSkewDex");
  const proxy = await hre.upgrades.deployProxy(ArbEmpire, [owner.address]);
  await proxy.deployed();
  console.log("Proxy:", proxy.address);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});