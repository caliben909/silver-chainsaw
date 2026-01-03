const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GodModeEmpire", function () {
  let GodModeEmpire, godModeEmpire, owner, treasury, skimRouter;

  beforeEach(async function () {
    [owner, treasury] = await ethers.getSigners();
    const SkimRouter = await ethers.getContractFactory("SkimRouter");
    skimRouter = await SkimRouter.deploy(treasury.address);
    await skimRouter.deployed();

    GodModeEmpire = await ethers.getContractFactory("GodModeEmpire");
    godModeEmpire = await GodModeEmpire.deploy(skimRouter.address, treasury.address);
    await godModeEmpire.deployed();
  });

  it("Should deploy with correct parameters", async function () {
    expect(await godModeEmpire.owner()).to.equal(owner.address);
    expect(await godModeEmpire.SKIM_ROUTER()).to.equal(skimRouter.address);
  });

  it("Should allow owner to set dev fee", async function () {
    await godModeEmpire.setDevFee(10);
    expect(await godModeEmpire.devFeeBP()).to.equal(10);
  });

  it("Should allow owner to set max trade size", async function () {
    await godModeEmpire.setMaxTradeSize(2000000e6);
    expect(await godModeEmpire.maxTradeSize()).to.equal(2000000e6);
  });

  it("Should pause and unpause", async function () {
    await godModeEmpire.pause();
    expect(await godModeEmpire.paused()).to.equal(true);
    await godModeEmpire.unpause();
    expect(await godModeEmpire.paused()).to.equal(false);
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
    console.log("AAVE:", await godModeEmpire.AAVE());
    console.log("ARB:", await godModeEmpire.ARB());
    console.log("LDO:", await godModeEmpire.LDO());
    console.log("CRV:", await godModeEmpire.CRV());
    console.log("PEPE:", await godModeEmpire.PEPE());
    console.log("BONK:", await godModeEmpire.BONK());
  });
});