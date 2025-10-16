import {
  createPublicClient,
  http,
  Hex,
  encodeFunctionData,
  Address
} from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { sepolia } from 'viem/chains';
import { createSmartAccountClient } from 'permissionless';
import { createPimlicoClient } from 'permissionless/clients/pimlico';
import { toSimpleSmartAccount } from 'permissionless/accounts';
import { entryPoint07Address, waitForUserOperationReceipt, getUserOperationHash } from 'viem/account-abstraction';
import { sign, serializeSignature } from 'viem/accounts';
import 'dotenv/config';

const rpcUrl = process.env.SEPOLIA_RPC_URL as string;
const privateKey = process.env.PRIVATE_KEY as Hex;
const bundlerUrl = process.env.BUNDLER_URL as string;
const walletProxyInstance = process.env.WALLET_PROXY_INSTANCE as Address;
const simpleTarget = process.env.SIMPLE_TARGET as Address;

if (!rpcUrl || !privateKey || !bundlerUrl || !walletProxyInstance || !simpleTarget) {
  console.error("Please provide SEPOLIA_RPC_URL, PRIVATE_KEY, BUNDLER_URL, WALLET_PROXY_INSTANCE, and SIMPLE_TARGET environment variables.");
  process.exit(1);
}

// ########### Ethereum Córdoba ###########

// --- Network Configuration ---
const chain = sepolia;

// --- Public Client ---
// Client to interact with the blockchain (read data, send transactions from EOA)
const publicClient = createPublicClient({
  transport: http(rpcUrl),
  chain,
});

// --- Owner Account (EOA) ---
// The EOA that will be the signer for the smart account and fund the EntryPoint
const owner = privateKeyToAccount(privateKey);

// --- Pimlico Client (handles bundler actions) ---
const pimlicoClient = createPimlicoClient({
  transport: http(bundlerUrl),
  entryPoint: {
      address: entryPoint07Address,
      version: "0.7", // Explicitly specify version V0.7
  },
});

// ABI for the SimpleTargetContract with a setValue function
const simpleTargetContractABI = [
  {
    inputs: [{ name: "_newValue", type: "uint256" }],
    name: "setValue",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
] as const;

// ABI for the smart account implementation with an execute function
// This ABI should match the ABI of the walletImplementation execute function
const smartAccountExecuteABI = [
  {
    inputs: [
      { name: "dest", type: "address" },
      { name: "value", type: "uint256" },
      { name: "funcCallData", type: "bytes" },
    ],
    name: "execute",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
] as const;

// --- Main Function ---
async function main() {
  // 1. Provide the existing smart account proxy address
  const smartAccount = await toSimpleSmartAccount({
    client: publicClient, // Provide the public client for blockchain interaction
    entryPoint: {
        address: entryPoint07Address,
        version: "0.7", // Explicitly specify the version V0.7
    },
    address: walletProxyInstance, // existing proxy instance
    owner, // the EOA that will control this smart account
  });

  const smartAccountAddress = smartAccount.address;
  console.log(`Smart account INSTANCE address: ${smartAccountAddress}`);

  // 2. Deposit funds to the EntryPoint for the smart account

  // 3. Create the smart account client
  // Bundler client used to prepare, sign, and send user operations.
  // It uses the bundlerTransport to interact with the bundler.
  const smartAccountClient = createSmartAccountClient({
    account: smartAccount, // The smart account instance (representing your proxy)
    chain, // The network chain
    bundlerTransport: http(bundlerUrl), // The bundler RPC endpoint
	userOperation: {
		estimateFeesPerGas: async () => {
			return (await pimlicoClient.getUserOperationGasPrice()).standard
		},
	},    
  });

  // 4. Build the user operation with the specified calldata
  console.log("Building user operation with custom calldata...");

  // --- Define the target contract and function call ---
  // The address of the contract you want the smart account (proxy) to interact with
  const simpleTargetContract: Address = simpleTarget;
  const newValueToSet = 123; // Test value to set in the target contract

  // Encode the call data for the target function (e.g., setValue on SimpleTargetContract)
  const targetCallData = encodeFunctionData({
    abi: simpleTargetContractABI,
    functionName: "setValue",
    args: [BigInt(newValueToSet)], // Use BigInt for uint256 arguments
  });

  // --- Calling execute on the wallet (proxy) ---
  // The UserOperation's callData should call the smart account's execute function on the PROXY.
  // The execute function on the proxy then delegates the call to the implementation.
  const walletCallData = encodeFunctionData({
    abi: smartAccountExecuteABI, // Use the ABI for your smart account's execute function
    functionName: "execute",
    args: [
      simpleTargetContract, // The address of the target contract to call
      BigInt(0), // The value (ETH) to send with the target call (0 in this case)
      targetCallData, // The encoded call data for the target function
    ],
  });

  // === Send the UserOperation ===  
  console.log('[4/4] Sending UserOperation to the bundler...');
  
  const gasPrices = await pimlicoClient.getUserOperationGasPrice();

  const preparedUserOperation = await smartAccountClient.prepareUserOperation({
    account: smartAccount,
    callData: walletCallData,
    maxFeePerGas: gasPrices.fast.maxFeePerGas,
    maxPriorityFeePerGas: gasPrices.fast.maxPriorityFeePerGas,
  });

  const uoHash = getUserOperationHash({
    chainId: sepolia.id,
    entryPointAddress: entryPoint07Address,
    entryPointVersion: '0.7',
    userOperation: preparedUserOperation,
  });

  const signature = serializeSignature(await sign({ hash: uoHash, privateKey }));
  preparedUserOperation.signature = signature;

  const userOperationHash = await smartAccountClient.sendUserOperation(preparedUserOperation);

  console.log(`   - UserOperation hash: ${userOperationHash}`);
  console.log('   - Waiting for transaction to be included...');  

  // Wait for the user operation to be processed by the bundler and included in a transaction on-chain.
  // Use the imported waitForUserOperationReceipt from viem/account-abstraction
  const receipt = await waitForUserOperationReceipt(pimlicoClient, {
    hash: userOperationHash,
    timeout: 100000, // Increase timeout if needed (e.g., for slower testnets)
  });

  console.log("User Operation Receipt:", receipt);
  console.log(`User operation included in block: ${receipt.receipt.blockNumber}`);
  console.log(`Transaction hash: ${receipt.receipt.transactionHash}`);
}

main().catch(console.error);
