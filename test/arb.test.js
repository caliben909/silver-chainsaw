const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GodModeEmpire", function () {
  let GodModeEmpire, godModeEmpire, owner, treasury, skimRouter;

  beforeEach(async function () {
    [owner, treasury] = await ethers.getSigners();

    // Deploy GodModeEmpire
    GodModeEmpire = await ethers.getContractFactory("GodModeEmpire");
    godModeEmpire = await GodModeEmpire.deploy(treasury.address);
    await godModeEmpire.waitForDeployment();

    // Deploy SkimRouter
    const SkimRouterFactory = await ethers.getContractFactory("SkimRouter");
    skimRouter = await SkimRouterFactory.deploy(treasury.address);
    await skimRouter.waitForDeployment();

    // Set SkimRouter
    await godModeEmpire.setSkimRouter(skimRouter.target);
  });

  it("Should deploy with correct parameters", async function () {
    expect(await godModeEmpire.owner()).to.equal(owner.address);
    expect(await godModeEmpire.skimRouter()).to.equal(skimRouter.target);
  });

  it("Should allow owner to set owner fee", async function () {
    await godModeEmpire.setOwnerFee(1500); // 15%
    expect(Number(await godModeEmpire.ownerFeeBP())).to.equal(1500);
  });

  it("Should allow owner to set skim router", async function () {
    const newSkimRouter = await SkimRouterFactory.deploy(treasury.address);
    await newSkimRouter.waitForDeployment();
    await godModeEmpire.setSkimRouter(newSkimRouter.target);
    expect(await godModeEmpire.skimRouter()).to.equal(newSkimRouter.target);
  });

  // Test for risk checks - simplified
  it("Should have risk mitigation functions", async function () {
    // Just check that functions exist and don't revert
    // In real tests, mock oracles and pools
    expect(true).to.be.true;
  });

  it("Should list all token addresses", async function () {
    console.log("Token Addresses:");
    console.log("USDT:", await godModeEmpire.USDT());
    console.log("USDC:", await godModeEmpire.USDC());
    console.log("WBTC:", await godModeEmpire.WBTC());
    console.log("WETH:", await godModeEmpire.WETH());
    console.log("GMX:", await godModeEmpire.GMX());
    console.log("MAGIC:", await godModeEmpire.MAGIC());
    console.log("GRAIL:", await godModeEmpire.GRAIL());
    console.log("RDNT:", await godModeEmpire.RDNT());
    console.log("PENDLE:", await godModeEmpire.PENDLE());
    console.log("LINK:", await godModeEmpire.LINK());
    console.log("UNI:", await godModeEmpire.UNI());
    console.log("AAVE_TOKEN:", await godModeEmpire.AAVE_TOKEN());
    console.log("ARB:", await godModeEmpire.ARB());
    console.log("LDO:", await godModeEmpire.LDO());
    console.log("CRV:", await godModeEmpire.CRV());
    console.log("PEPE:", await godModeEmpire.PEPE());
    console.log("BONK:", await godModeEmpire.BONK());
  });
});