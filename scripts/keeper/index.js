const { ethers } = require("ethers");
const { FlashbotsBundleProvider } = require("@flashbots/ethers-provider-bundle");
const { opportunity } = require("./opportunity");
const cfg = require("../../config");

const provider = new ethers.providers.JsonRpcProvider(cfg.rpc.primary);
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
const authSigner = new ethers.Wallet(process.env.FLASHBOTS_SIGNATURE, provider);

let fbProvider;

async function init() {
  fbProvider = await FlashbotsBundleProvider.create(provider, authSigner);
  console.log("Flashbots provider ready");
  loop();
}

async function loop() {
  while (true) {
    try {
      const opp = await opportunity(wallet.address);
      if (opp.profitWei.gt(0)) {
        const tx = await opp.toTx();
        const bundle = await fbProvider.sendBundle([tx], opp.targetBlock);
        console.log("Bundle hash", bundle.bundleHash);
      }
    } catch (e) {
      console.error("Keeper error", e.message);
    }
    await new Promise(r => setTimeout(r, 1200)); // 1.2 s
  }
}

init();