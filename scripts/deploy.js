const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("Deploying GodModeEmpire with account:", deployer.address);

  const SKIM_ROUTER_ADDRESS = "0x3395B3D85f4629271b85514A7841040F4B669aBf"; // Paste from Step 5
  const TREASURY_ADDRESS = deployer.address;

  const GodModeEmpire = await hre.ethers.getContractFactory("GodModeEmpire");
  const empire = await GodModeEmpire.deploy(SKIM_ROUTER_ADDRESS, TREASURY_ADDRESS);

  await empire.waitForDeployment();

  console.log("GodModeEmpire deployed to:", await empire.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});