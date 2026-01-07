const hre = require("hardhat");

async function main() {
  const godModeEmpireAddress = "0x5525F0c3f9e0F8186a0796FBea3C418dcfeAcc73"; // Replace with actual
  const mcpDistributorAddress = "0x98Fd0043C90f58c8983F1BAC2e5F0913cFEed8B3"; // Replace with actual

  const GodModeEmpire = await hre.ethers.getContractAt("GodModeEmpire", godModeEmpireAddress);
  await GodModeEmpire.setMCPDistributorAddress(mcpDistributorAddress);
  console.log("MCP Distributor address set");
}

main().catch(console.error);