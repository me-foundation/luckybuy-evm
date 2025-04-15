import { ethers } from "ethers";
import * as dotenv from "dotenv";
import {
  getLuckyBuyContract,
  getProvider,
  getWallets,
  formatEth,
  parseEth,
} from "./contractUtils";

// Load environment variables
dotenv.config();

async function main() {
  console.log("=== LuckyBuy Commit and Fulfill Example ===");

  // Connect to provider and get wallets
  const provider = getProvider();
  const { deployer, cosigner, user } = getWallets(provider);

  // Get contract instance with user account
  const luckyBuy = await getLuckyBuyContract(user);

  // Display initial balances
  console.log("\nInitial Balances:");
  console.log(
    `User: ${formatEth(await provider.getBalance(user.address))} ETH`
  );
  console.log(`Treasury: ${formatEth(await luckyBuy.treasuryBalance())} ETH`);
  console.log(
    `Commit Balance: ${formatEth(await luckyBuy.commitBalance())} ETH`
  );

  // Create parameters for commit
  const receiver = user.address;
  const cosignerAddress = cosigner.address;
  const seed = 12345;
  const reward = parseEth("1.0"); // 1 ETH reward
  const commitAmount = parseEth("0.5"); // 0.5 ETH commit (50% chance of winning)

  // Get zero address
  const zeroAddress = ethers.ZeroAddress;

  // Create order hash
  console.log("\nCreating order hash...");
  // Create order hash
  const orderHash = ethers.keccak256(
    ethers.solidityPacked(
      ["address", "uint256", "bytes", "address", "uint256"],
      [zeroAddress, reward, "0x", zeroAddress, 0]
    )
  );
  console.log(`Order hash: ${orderHash}`);

  // Create commit
  console.log("\nCreating commit...");
  console.log(`Commit amount: ${formatEth(commitAmount)} ETH`);
  console.log(`Reward amount: ${formatEth(reward)} ETH`);

  const commitTx = await luckyBuy.commit(
    receiver,
    cosignerAddress,
    seed,
    orderHash,
    reward,
    { value: commitAmount }
  );

  // Wait for transaction
  console.log("Waiting for commit transaction...");
  const commitReceipt = await commitTx.wait();

  if (!commitReceipt) {
    throw new Error("Failed to get commit transaction receipt");
  }

  // Extract commit ID from events
  const commitEvents = commitReceipt.logs.filter(
    (log) =>
      log.topics[0] ===
      ethers.id(
        "Commit(address,uint256,address,address,uint256,uint256,bytes32,uint256,uint256,uint256,bytes32)"
      )
  );

  if (commitEvents.length === 0) {
    throw new Error("No Commit event found in transaction receipt");
  }

  // Parse the event data (we're looking for the commitId which is the second indexed parameter)
  const commitId = parseInt(commitEvents[0].topics[2], 16);
  console.log(`Commit created with ID: ${commitId}`);

  // Display post-commit balances
  console.log("\nBalances after commit:");
  console.log(
    `User: ${formatEth(await provider.getBalance(user.address))} ETH`
  );
  console.log(`Treasury: ${formatEth(await luckyBuy.treasuryBalance())} ETH`);
  console.log(
    `Commit Balance: ${formatEth(await luckyBuy.commitBalance())} ETH`
  );

  // Get commit data
  const commitData = await luckyBuy.luckyBuys(commitId);
  console.log("\nCommit data:");
  console.log(`Receiver: ${commitData.receiver}`);
  console.log(`Cosigner: ${commitData.cosigner}`);
  console.log(`Amount: ${formatEth(commitData.amount)} ETH`);
  console.log(`Reward: ${formatEth(commitData.reward)} ETH`);

  // Calculate commit digest for signature
  const digest = await luckyBuy.hash(commitData);
  console.log(`Commit digest: ${digest}`);

  // Sign the digest with cosigner
  const signature = await cosigner.signMessage(ethers.getBytes(digest));
  console.log(`Cosigner signature: ${signature}`);

  // Fulfill the commit
  console.log("\nFulfilling commit...");
  const fulfillTx = await luckyBuy.fulfill(
    commitId,
    zeroAddress, // marketplace
    "0x", // orderData
    reward, // orderAmount
    zeroAddress, // token
    0, // tokenId
    signature
  );

  console.log("Waiting for fulfill transaction...");
  const fulfillReceipt = await fulfillTx.wait();

  if (!fulfillReceipt) {
    throw new Error("Failed to get fulfill transaction receipt");
  }

  // Check fulfillment events to see if user won
  const fulfillEvents = fulfillReceipt.logs.filter(
    (log) =>
      log.topics[0] ===
      ethers.id(
        "Fulfillment(address,uint256,uint256,uint256,bool,address,uint256,uint256,address,uint256,bytes32)"
      )
  );

  if (fulfillEvents.length === 0) {
    throw new Error("No Fulfillment event found in transaction receipt");
  }

  // Final balances
  console.log("\nFinal Balances:");
  console.log(
    `User: ${formatEth(await provider.getBalance(user.address))} ETH`
  );
  console.log(`Treasury: ${formatEth(await luckyBuy.treasuryBalance())} ETH`);
  console.log(
    `Commit Balance: ${formatEth(await luckyBuy.commitBalance())} ETH`
  );

  // Determine if the user won by comparing the before and after treasury balance
  const userFinalBalance = await provider.getBalance(user.address);
  console.log(
    `\nUser balance difference after fulfilment: ${formatEth(
      userFinalBalance
    )} ETH`
  );

  console.log("\nTransaction complete!");
}

// Run the example
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error:", error);
    process.exit(1);
  });
