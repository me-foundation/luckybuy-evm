import { ethers } from "ethers";
import * as dotenv from "dotenv";
import * as fs from "fs";
import * as path from "path";
import {
  LuckyBuyContract,
  CONFIG,
  getProvider,
  getWallets,
  formatEth,
} from "./contractUtils";

// Load environment variables
dotenv.config();

async function main() {
  console.log("Deploying LuckyBuy contract to local Anvil instance...");
  console.log(`RPC URL: ${CONFIG.RPC_URL}`);

  // Connect to local Anvil node
  const provider = getProvider();

  // Set up wallets
  const {
    deployer: deployerWallet,
    cosigner: cosignerWallet,
    user: userWallet,
  } = getWallets(provider);

  console.log("Deployer address:", deployerWallet.address);
  console.log("Cosigner address:", cosignerWallet.address);
  console.log("User address:", userWallet.address);

  // Get deployer balance
  const deployerBalance = await provider.getBalance(deployerWallet.address);
  console.log(`Deployer balance: ${formatEth(deployerBalance)} ETH`);

  // Load contract artifacts (from Foundry's out directory)
  const artifactPath = path.join(__dirname, CONFIG.ARTIFACT_PATH);
  console.log(`Loading artifact from: ${artifactPath}`);

  const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));

  // Deploy LuckyBuy contract
  console.log(
    `Deploying LuckyBuy contract with protocol fee: ${CONFIG.PROTOCOL_FEE}...`
  );

  const factory = new ethers.ContractFactory(
    artifact.abi,
    artifact.bytecode,
    deployerWallet
  );

  const deployedContract = await factory.deploy(CONFIG.PROTOCOL_FEE);
  await deployedContract.waitForDeployment();

  // Cast to our interface type
  const luckyBuy = deployedContract as unknown as LuckyBuyContract;

  const contractAddress = await luckyBuy.getAddress();
  console.log("LuckyBuy deployed to:", contractAddress);

  // Fund the contract with ETH for rewards
  const fundingAmount = ethers.parseEther(CONFIG.FUNDING_AMOUNT);
  console.log(
    `Funding contract with ${CONFIG.FUNDING_AMOUNT} ETH for rewards...`
  );

  const fundTx = await deployerWallet.sendTransaction({
    to: contractAddress,
    value: fundingAmount,
  });
  await fundTx.wait();
  console.log("Contract funded successfully");

  // Add cosigner to contract
  console.log("Adding cosigner to contract...");
  const addCosignerTx = await luckyBuy.addCosigner(cosignerWallet.address);
  await addCosignerTx.wait();
  console.log("Cosigner added successfully");

  // Print summary
  console.log("\nDeployment Summary:");
  console.log("-------------------");
  console.log(`Contract Address: ${contractAddress}`);
  console.log(`Deployer Address: ${deployerWallet.address}`);
  console.log(`Cosigner Address: ${cosignerWallet.address}`);
  console.log(`User Address: ${userWallet.address}`);
  console.log(`Protocol Fee: ${CONFIG.PROTOCOL_FEE}`);
  console.log(`Funding Amount: ${CONFIG.FUNDING_AMOUNT} ETH`);

  // Save deployment info to a file
  const deploymentInfo = {
    networkName: "anvil",
    chainId: CONFIG.CHAIN_ID,
    rpcUrl: CONFIG.RPC_URL,
    contractAddress,
    deployerAddress: deployerWallet.address,
    cosignerAddress: cosignerWallet.address,
    userAddress: userWallet.address,
    protocolFee: CONFIG.PROTOCOL_FEE,
    fundingAmount: CONFIG.FUNDING_AMOUNT,
    deploymentTimestamp: new Date().toISOString(),
  };

  fs.writeFileSync(
    path.join(__dirname, CONFIG.DEPLOYMENT_INFO_PATH),
    JSON.stringify(deploymentInfo, null, 2)
  );

  console.log(`Deployment information saved to ${CONFIG.DEPLOYMENT_INFO_PATH}`);
}

// Run the deployment script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error during deployment:", error);
    process.exit(1);
  });
