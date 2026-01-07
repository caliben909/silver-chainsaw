const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Deploying MCPDistributor...");

  // Get deployer
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  // Deploy MCPDistributor
  const MCPDistributor = await ethers.getContractFactory("MCPDistributor");
  const distributor = await MCPDistributor.deploy();
  await distributor.waitForDeployment();

  const distributorAddress = await distributor.getAddress();
  console.log("✅ MCPDistributor deployed to:", distributorAddress);

  // Set initial wallets (placeholder - update with real addresses)
  const placeholderWallets = Array(10).fill("0x0000000000000000000000000000000000000000");
  await distributor.setWallets(placeholderWallets);
  console.log("✅ Placeholder wallets set");

  console.log("\n📋 Deployment Summary:");
  console.log("MCPDistributor:", distributorAddress);
  console.log("\n⚠️  IMPORTANT: Update wallets with real addresses using setWallets()");

  // Save to .env or output
  console.log("\n💾 Add to your .env:");
  console.log(`DISTRIBUTOR_ADDRESS=${distributorAddress}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });