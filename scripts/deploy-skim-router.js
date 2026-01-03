const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("Deploying SkimRouter with account:", deployer.address);

  const SkimRouter = await hre.ethers.getContractFactory("SkimRouter");
  const skimRouter = await SkimRouter.deploy(deployer.address); // Treasury = deployer

  await skimRouter.waitForDeployment();

  console.log("SkimRouter deployed to:", await skimRouter.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});