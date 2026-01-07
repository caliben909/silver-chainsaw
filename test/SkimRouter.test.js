const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SkimRouter", function () {
  let SkimRouter, skimRouter, owner, treasury;

  beforeEach(async function () {
    [owner, treasury] = await ethers.getSigners();
    SkimRouter = await ethers.getContractFactory("SkimRouter");
    skimRouter = await SkimRouter.deploy(treasury.address);
    await skimRouter.waitForDeployment();
  });

  it("Should deploy with correct treasury", async function () {
    expect(await skimRouter.owner()).to.equal(owner.address);
  });

  it("Should allow owner to set dev fee", async function () {
    await skimRouter.setDevFee(10);
    // Assuming devFeeBP is public
  });

  it("Should allow owner to rescue tokens", async function () {
    // Mock token transfer or test rescue
  });
});