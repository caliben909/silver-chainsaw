require('dotenv').config();
const { ethers } = require('ethers');

// Multicall3 contract ABI (minimal for aggregate function)
const multicallAbi = [
  {
    inputs: [
      {
        components: [
          { internalType: 'address', name: 'target', type: 'address' },
          { internalType: 'bytes', name: 'callData', type: 'bytes' }
        ],
        internalType: 'struct Multicall3.Call[]',
        name: 'calls',
        type: 'tuple[]'
      }
    ],
    name: 'aggregate',
    outputs: [
      { internalType: 'uint256', name: 'blockNumber', type: 'uint256' },
      { internalType: 'bytes[]', name: 'returnData', type: 'bytes[]' }
    ],
    stateMutability: 'payable',
    type: 'function'
  }
];

// Multicall3 address (same on Ethereum mainnet and Arbitrum)
const MULTICALL_ADDRESS = '0xcA11bde05977b3631167028862bE2a173976CA11b';

/**
 * Validates input parameters for multicall
 * @param {string} infuraApiKey - Infura API key
 * @param {string} privateKey - Private key for signing
 * @param {Array} calls - Array of call objects {target: address, callData: hex string}
 * @param {string} network - Network name (e.g., 'mainnet', 'arbitrum')
 */
function validateInputs(infuraApiKey, privateKey, calls, network) {
  if (!infuraApiKey || typeof infuraApiKey !== 'string') {
    throw new Error('Invalid Infura API key');
  }
  if (!privateKey || typeof privateKey !== 'string' || !ethers.isHexString(privateKey, 32)) {
    throw new Error('Invalid private key');
  }
  if (!Array.isArray(calls) || calls.length === 0) {
    throw new Error('Calls must be a non-empty array');
  }
  for (const call of calls) {
    if (!call.target || !ethers.isAddress(call.target)) {
      throw new Error(`Invalid target address: ${call.target}`);
    }
    if (!call.callData || !ethers.isHexString(call.callData)) {
      throw new Error(`Invalid callData: ${call.callData}`);
    }
  }
  if (!network || typeof network !== 'string') {
    throw new Error('Invalid network');
  }
}

/**
 * Estimates gas for the multicall transaction
 * @param {ethers.Contract} multicallContract - Multicall contract instance
 * @param {Array} calls - Array of calls
 * @param {ethers.Wallet} wallet - Wallet instance
 * @returns {Promise<BigInt>} Estimated gas
 */
async function estimateGas(multicallContract, calls, wallet) {
  try {
    const tx = await multicallContract.aggregate.populateTransaction(calls);
    tx.from = wallet.address;
    const gasEstimate = await wallet.provider.estimateGas(tx);
    // Add 20% buffer for safety
    return (gasEstimate * 120n) / 100n;
  } catch (error) {
    throw new Error(`Gas estimation failed: ${error.message}`);
  }
}

/**
 * Executes atomic multicall transaction
 * @param {Array} calls - Array of {target, callData}
 * @param {string} network - Network (e.g., 'mainnet', 'arbitrum')
 * @returns {Promise<Object>} Transaction result
 */
async function executeAtomicMulticall(calls, network = 'arbitrum') {
  try {
    const infuraApiKey = process.env.INFURA_API_KEY;
    const privateKey = process.env.PRIVATE_KEY;

    // Validate inputs
    validateInputs(infuraApiKey, privateKey, calls, network);

    // Setup provider and wallet
    const infuraUrl = `https://${network}.infura.io/v3/${infuraApiKey}`;
    const provider = new ethers.JsonRpcProvider(infuraUrl);
    const wallet = new ethers.Wallet(privateKey, provider);

    // Multicall contract
    const multicallContract = new ethers.Contract(MULTICALL_ADDRESS, multicallAbi, wallet);

    // Estimate gas
    const gasLimit = await estimateGas(multicallContract, calls, wallet);
    console.log(`Estimated gas: ${gasLimit.toString()}`);

    // Prepare transaction
    const txRequest = await multicallContract.aggregate.populateTransaction(calls);
    txRequest.gasLimit = gasLimit;

    // Get current gas price
    const feeData = await provider.getFeeData();
    txRequest.maxFeePerGas = feeData.maxFeePerGas;
    txRequest.maxPriorityFeePerGas = feeData.maxPriorityFeePerGas;

    console.log('Sending transaction...');

    // Sign and send
    const txResponse = await wallet.sendTransaction(txRequest);
    console.log(`Transaction sent: ${txResponse.hash}`);

    // Monitor and wait for confirmation
    console.log('Waiting for confirmation...');
    const receipt = await txResponse.wait();
    console.log(`Transaction confirmed in block ${receipt.blockNumber}`);

    // Check if all operations succeeded (multicall aggregate succeeds only if all calls succeed)
    if (receipt.status === 1) {
      console.log('All operations executed atomically and successfully!');
      return {
        success: true,
        txHash: receipt.hash,
        blockNumber: receipt.blockNumber,
        gasUsed: receipt.gasUsed.toString()
      };
    } else {
      throw new Error('Transaction reverted');
    }

  } catch (error) {
    console.error(`Atomic multicall failed: ${error.message}`);
    return {
      success: false,
      error: error.message
    };
  }
}

// Example usage
async function main() {
  const network = 'arbitrum'; // or 'mainnet'

  // Example calls (replace with actual contract calls)
  const calls = [
    {
      target: '0xContractAddress1',
      callData: '0x...' // Encoded function call data
    },
    {
      target: '0xContractAddress2',
      callData: '0x...' // Another encoded call
    }
  ];

  const result = await executeAtomicMulticall(calls, network);
  console.log(result);
}

// Uncomment to run example
// main();

module.exports = { executeAtomicMulticall, validateInputs };