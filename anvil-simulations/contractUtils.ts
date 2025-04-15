import { ethers } from "ethers";
import * as dotenv from "dotenv";
import * as fs from "fs";
import * as path from "path";
import MagicSigner from "../cosigner-lib";

// tldr this is vibe coded. I wouldn't normally get this involved for testing/simulations.

// Load environment variables
dotenv.config();

// Define a CommitData interface for better type safety
export interface CommitData {
  id: number;
  receiver: string;
  cosigner: string;
  seed: bigint | number;
  counter: bigint | number;
  orderHash: string;
  amount: bigint;
  reward: bigint;
}

// Define interfaces for contract interaction
export interface LuckyBuyContract extends ethers.BaseContract {
  // Core functions
  addCosigner(cosigner: string): Promise<ethers.ContractTransactionResponse>;
  commit(
    receiver: string,
    cosigner: string,
    seed: bigint | number,
    orderHash: string,
    reward: bigint | number,
    options?: { value: bigint }
  ): Promise<ethers.ContractTransactionResponse>;
  fulfill(
    commitId: bigint | number,
    marketplace: string,
    orderData: string,
    orderAmount: bigint | number,
    token: string,
    tokenId: bigint | number,
    signature: string
  ): Promise<ethers.ContractTransactionResponse>;

  // View functions
  getAddress(): Promise<string>;
  isCosigner(cosigner: string): Promise<boolean>;
  treasuryBalance(): Promise<bigint>;
  commitBalance(): Promise<bigint>;
  protocolBalance(): Promise<bigint>;
  luckyBuys(id: bigint | number): Promise<CommitData>;
  commitIdByDigest(digest: string): Promise<bigint>;
  hash(commitData: CommitData): Promise<string>;

  // Admin functions
  setProtocolFee(
    fee: bigint | number
  ): Promise<ethers.ContractTransactionResponse>;
  setMaxReward(
    maxReward: bigint | number
  ): Promise<ethers.ContractTransactionResponse>;
  setMinReward(
    minReward: bigint | number
  ): Promise<ethers.ContractTransactionResponse>;
  removeCosigner(cosigner: string): Promise<ethers.ContractTransactionResponse>;
  pause(): Promise<ethers.ContractTransactionResponse>;
  unpause(): Promise<ethers.ContractTransactionResponse>;
}

// Config from environment
export const CONFIG = {
  // Network
  RPC_URL: process.env.ANVIL_RPC_URL || "http://localhost:8545",
  CHAIN_ID: parseInt(process.env.ANVIL_CHAIN_ID || "31337"),

  // Contract settings
  PROTOCOL_FEE: parseInt(process.env.PROTOCOL_FEE || "0"),
  FUNDING_AMOUNT: process.env.FUNDING_AMOUNT || "10",

  // Keys
  DEPLOYER_KEY:
    process.env.ANVIL_DEPLOYER_KEY ||
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
  COSIGNER_KEY:
    process.env.ANVIL_COSIGNER_KEY ||
    "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",
  USER_KEY:
    process.env.ANVIL_USER_KEY ||
    "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a",

  // Paths
  ARTIFACT_PATH:
    process.env.ARTIFACT_PATH || "../out/LuckyBuy.sol/LuckyBuy.json",
  DEPLOYMENT_INFO_PATH: process.env.DEPLOYMENT_INFO_PATH || "./deployment.json",
};

// Helper to load the deployment info
export function loadDeploymentInfo() {
  const deploymentPath = path.join(__dirname, CONFIG.DEPLOYMENT_INFO_PATH);

  if (!fs.existsSync(deploymentPath)) {
    throw new Error(
      `Deployment info not found at ${deploymentPath}. Run the deployment script first.`
    );
  }

  return JSON.parse(fs.readFileSync(deploymentPath, "utf8"));
}

// Helper to create contract instance
export async function getLuckyBuyContract(
  signerOrProvider?: ethers.Signer | ethers.Provider
): Promise<LuckyBuyContract> {
  // Load deployment info
  const deployment = loadDeploymentInfo();

  // Load contract ABI
  const artifactPath = path.join(__dirname, CONFIG.ARTIFACT_PATH);
  const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));

  // Set up provider if not provided
  let provider: ethers.Provider;
  if (!signerOrProvider) {
    provider = new ethers.JsonRpcProvider(CONFIG.RPC_URL);
  } else if ("provider" in signerOrProvider) {
    provider = signerOrProvider.provider as ethers.Provider;
  } else {
    provider = signerOrProvider;
  }

  // Create contract instance
  if (signerOrProvider && "provider" in signerOrProvider) {
    // With signer
    return new ethers.Contract(
      deployment.contractAddress,
      artifact.abi,
      signerOrProvider
    ) as unknown as LuckyBuyContract;
  } else {
    // Read-only
    return new ethers.Contract(
      deployment.contractAddress,
      artifact.abi,
      provider
    ) as unknown as LuckyBuyContract;
  }
}

// Helper to get wallet instances
export function getWallets(provider: ethers.Provider) {
  return {
    deployer: new ethers.Wallet(CONFIG.DEPLOYER_KEY, provider),
    cosigner: new ethers.Wallet(CONFIG.COSIGNER_KEY, provider),
    user: new ethers.Wallet(CONFIG.USER_KEY, provider),
  };
}

// Helper to connect to Anvil
export function getProvider() {
  return new ethers.JsonRpcProvider(CONFIG.RPC_URL);
}

// Helper to format ETH values
export function formatEth(value: bigint): string {
  return ethers.formatEther(value);
}

// Helper to parse ETH values
export function parseEth(value: string): bigint {
  return ethers.parseEther(value);
}

// Helper function to get MagicSigner instance
export function getMagicSigner(
  contractAddress: string,
  privateKey: string,
  chainId: number
): MagicSigner {
  return new MagicSigner({
    contract: contractAddress,
    privateKey: privateKey,
    chainId: chainId,
  });
}
