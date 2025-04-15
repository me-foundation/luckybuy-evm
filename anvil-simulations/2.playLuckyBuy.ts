import { ethers } from "ethers";
import * as dotenv from "dotenv";
import {
  getLuckyBuyContract,
  getProvider,
  getWallets,
  formatEth,
  parseEth,
  LuckyBuyContract,
  CommitData,
  getMagicSigner,
  CONFIG,
} from "./contractUtils";
import MagicSigner from "../cosigner-lib";

// Load environment variables
dotenv.config();

// Config for this simulation
const SIMULATION_CONFIG = {
  // Number of games to play
  GAMES_TO_PLAY: parseInt(process.env.GAMES_TO_PLAY || "3"),

  // Game parameters
  REWARD_AMOUNT: process.env.REWARD_AMOUNT || "1.0", // ETH
  COMMIT_AMOUNT: process.env.COMMIT_AMOUNT || "0.5", // ETH

  // Delay between games (ms)
  DELAY_BETWEEN_GAMES: parseInt(process.env.DELAY_BETWEEN_GAMES || "1000"),
};

/**
 * Create a simple orderHash for the reward amount using MagicSigner
 */
async function createOrderHash(
  magicSigner: MagicSigner,
  rewardAmount: bigint
): Promise<string> {
  const zeroAddress = ethers.ZeroAddress;

  return await magicSigner.hashOrder(
    zeroAddress,
    rewardAmount,
    "0x", // empty data
    zeroAddress,
    0 // tokenId
  );
}

/**
 * Create a commit for the LuckyBuy contract
 */
async function createCommit(
  luckyBuy: LuckyBuyContract,
  user: ethers.Wallet,
  cosigner: ethers.Wallet,
  magicSigner: MagicSigner,
  commitAmount: bigint,
  rewardAmount: bigint
): Promise<number> {
  console.log("\n📝 Creating new commit...");
  console.log(`Commit amount: ${formatEth(commitAmount)} ETH`);
  console.log(`Reward amount: ${formatEth(rewardAmount)} ETH`);

  // Game parameters
  const receiver = user.address;
  const cosignerAddress = cosigner.address;
  const seed = Math.floor(Math.random() * 1000000); // Random seed
  const orderHash = await createOrderHash(magicSigner, rewardAmount);

  console.log(`Seed: ${seed}`);
  console.log(`Order hash: ${orderHash}`);

  // Create commit transaction
  const commitTx = await luckyBuy.commit(
    receiver,
    cosignerAddress,
    seed,
    orderHash,
    rewardAmount,
    { value: commitAmount }
  );

  console.log(`Transaction sent: ${commitTx.hash}`);
  console.log("Waiting for transaction confirmation...");

  const receipt = await commitTx.wait();

  if (!receipt) {
    throw new Error("Failed to get commit transaction receipt");
  }

  // Extract commit ID from events
  const commitEvents = receipt.logs.filter(
    (log: any) =>
      log.topics[0] ===
      ethers.id(
        "Commit(address,uint256,address,address,uint256,uint256,bytes32,uint256,uint256,uint256,bytes32)"
      )
  );

  if (commitEvents.length === 0) {
    throw new Error("No Commit event found in transaction receipt");
  }

  // Parse the event data (commitId is the second indexed parameter)
  const commitId = parseInt(commitEvents[0].topics[2], 16);
  console.log(`✅ Commit created with ID: ${commitId}`);

  return commitId;
}

/**
 * Fulfill a commit and check the result using MagicSigner
 */
async function fulfillCommit(
  luckyBuy: LuckyBuyContract,
  commitId: number,
  cosigner: ethers.Wallet,
  magicSigner: MagicSigner,
  rewardAmount: bigint
): Promise<boolean> {
  console.log(`\n🎲 Fulfilling commit ${commitId}...`);

  // Get commit data
  const commitData = await luckyBuy.luckyBuys(commitId);
  console.log("Commit data:");
  console.log(`Receiver: ${commitData.receiver}`);
  console.log(`Amount: ${formatEth(commitData.amount)} ETH`);
  console.log(`Reward: ${formatEth(commitData.reward)} ETH`);

  // Calculate odds as percentage
  const amountFloat = parseFloat(ethers.formatEther(commitData.amount));
  const rewardFloat = parseFloat(ethers.formatEther(commitData.reward));
  const odds = (amountFloat / rewardFloat) * 100;
  console.log(`Odds of winning: ${odds.toFixed(2)}%`);

  // Use MagicSigner to sign the commit
  const signResult = await magicSigner.signCommit(
    BigInt(commitId),
    commitData.receiver,
    commitData.cosigner,
    BigInt(commitData.seed),
    BigInt(commitData.counter),
    commitData.orderHash,
    BigInt(commitData.amount),
    BigInt(commitData.reward)
  );

  console.log(`Cosigner signature created using MagicSigner`);
  console.log(`Digest: ${signResult.digest.substring(0, 10)}...`);

  // Get balances before fulfillment
  const treasuryBefore = await luckyBuy.treasuryBalance();
  const commitBalanceBefore = await luckyBuy.commitBalance();

  // Fulfill the commit
  const zeroAddress = ethers.ZeroAddress;
  const fulfillTx = await luckyBuy.fulfill(
    commitId,
    zeroAddress, // marketplace
    "0x", // orderData
    rewardAmount, // orderAmount
    zeroAddress, // token
    0, // tokenId
    signResult.signature
  );

  console.log(`Transaction sent: ${fulfillTx.hash}`);
  console.log("Waiting for transaction confirmation...");

  const receipt = await fulfillTx.wait();

  if (!receipt) {
    throw new Error("Failed to get fulfill transaction receipt");
  }

  // Check fulfillment events to see if user won
  const fulfillEvents = receipt.logs.filter(
    (log: any) =>
      log.topics[0] ===
      ethers.id(
        "Fulfillment(address,uint256,uint256,uint256,bool,address,uint256,uint256,address,uint256,bytes32)"
      )
  );

  if (fulfillEvents.length === 0) {
    throw new Error("No Fulfillment event found in transaction receipt");
  }

  // Get new balances after fulfillment
  const treasuryAfter = await luckyBuy.treasuryBalance();
  const commitBalanceAfter = await luckyBuy.commitBalance();

  // Try to decode the Fulfillment event and get the win status directly
  let didWin = false;

  try {
    // First try to detect from treasury balance change (most reliable)
    didWin = treasuryAfter < treasuryBefore;

    // Try to parse the event data
    // The topics are indexed as follows:
    // topics[0]: event signature
    // topics[1]: sender (indexed)
    // topics[2]: commitId (indexed)

    const logDescription = `Event: Fulfillment
    commitId: ${commitId}
    treasuryBefore: ${formatEth(treasuryBefore)} ETH
    treasuryAfter: ${formatEth(treasuryAfter)} ETH
    treasuryChange: ${formatEth(treasuryAfter - treasuryBefore)} ETH
    commitBalanceBefore: ${formatEth(commitBalanceBefore)} ETH
    commitBalanceAfter: ${formatEth(commitBalanceAfter)} ETH
    commitBalanceChange: ${formatEth(
      commitBalanceAfter - commitBalanceBefore
    )} ETH`;

    console.log(logDescription);
  } catch (error) {
    console.warn("Error parsing event:", error);
  }

  // Display the result with emojis and details
  if (didWin) {
    console.log(`\n🎯 Result: WON! 🎉🎉🎉`);
    console.log(
      `You won ${formatEth(commitData.reward)} ETH by betting ${formatEth(
        commitData.amount
      )} ETH!`
    );
    console.log(
      `Net profit: ${formatEth(commitData.reward - commitData.amount)} ETH`
    );
  } else {
    console.log(`\n🎯 Result: Lost 😢`);
    console.log(`You lost ${formatEth(commitData.amount)} ETH`);
  }

  return didWin;
}

/**
 * Display contract and account balances
 */
async function displayBalances(
  provider: ethers.Provider,
  luckyBuy: LuckyBuyContract,
  user: ethers.Wallet
) {
  console.log("\n💰 Current Balances:");
  console.log(
    `User: ${formatEth(await provider.getBalance(user.address))} ETH`
  );
  console.log(`Treasury: ${formatEth(await luckyBuy.treasuryBalance())} ETH`);
  console.log(
    `Commit Balance: ${formatEth(await luckyBuy.commitBalance())} ETH`
  );
  console.log(
    `Protocol Balance: ${formatEth(await luckyBuy.protocolBalance())} ETH`
  );
}

/**
 * Play multiple LuckyBuy games
 */
async function playGames(numGames: number) {
  // Connect to provider and get wallets
  const provider = getProvider();
  const { deployer, cosigner, user } = getWallets(provider);

  // Get contract instance with user account
  const luckyBuy = await getLuckyBuyContract(user);

  // Get the contract address
  const contractAddress = await luckyBuy.getAddress();

  // Create MagicSigner instance
  const magicSigner = getMagicSigner(
    contractAddress,
    cosigner.privateKey,
    CONFIG.CHAIN_ID
  );

  console.log("=== LuckyBuy Simulation ===");
  console.log(`Running ${numGames} games`);
  console.log(`Reward amount: ${SIMULATION_CONFIG.REWARD_AMOUNT} ETH`);
  console.log(`Commit amount: ${SIMULATION_CONFIG.COMMIT_AMOUNT} ETH`);
  console.log(`Contract address: ${contractAddress}`);
  console.log(`Cosigner address: ${cosigner.address}`);
  console.log(`Using MagicSigner for signatures`);

  // Convert amounts to bigint
  const rewardAmount = parseEth(SIMULATION_CONFIG.REWARD_AMOUNT);
  const commitAmount = parseEth(SIMULATION_CONFIG.COMMIT_AMOUNT);

  // Display initial balances
  await displayBalances(provider, luckyBuy, user);

  // Run games
  const results: (boolean | null)[] = [];

  for (let i = 0; i < numGames; i++) {
    console.log(`\n🎮 Game ${i + 1}/${numGames} 🎮`);

    try {
      // Create commit
      const commitId = await createCommit(
        luckyBuy,
        user,
        cosigner,
        magicSigner,
        commitAmount,
        rewardAmount
      );

      // Add delay to make it easier to follow in the console
      if (SIMULATION_CONFIG.DELAY_BETWEEN_GAMES > 0) {
        console.log(`Waiting ${SIMULATION_CONFIG.DELAY_BETWEEN_GAMES}ms...`);
        await new Promise((resolve) =>
          setTimeout(resolve, SIMULATION_CONFIG.DELAY_BETWEEN_GAMES)
        );
      }

      // Fulfill commit
      const didWin = await fulfillCommit(
        luckyBuy,
        commitId,
        cosigner,
        magicSigner,
        rewardAmount
      );

      // Store result
      results.push(didWin);

      // Show current balances
      await displayBalances(provider, luckyBuy, user);

      // Add delay between games
      if (i < numGames - 1 && SIMULATION_CONFIG.DELAY_BETWEEN_GAMES > 0) {
        console.log(
          `\nWaiting ${SIMULATION_CONFIG.DELAY_BETWEEN_GAMES}ms before next game...`
        );
        await new Promise((resolve) =>
          setTimeout(resolve, SIMULATION_CONFIG.DELAY_BETWEEN_GAMES)
        );
      }
    } catch (error) {
      console.error(`Error in game ${i + 1}:`, error);
      results.push(null); // Mark as error
    }
  }

  // Show final results
  const wins = results.filter((x) => x === true).length;
  const losses = results.filter((x) => x === false).length;
  const errors = results.filter((x) => x === null).length;

  console.log("\n📊 Final Results:");
  console.log(`Games played: ${numGames}`);
  console.log(`Wins: ${wins} (${((wins / numGames) * 100).toFixed(2)}%)`);
  console.log(`Losses: ${losses} (${((losses / numGames) * 100).toFixed(2)}%)`);

  if (errors > 0) {
    console.log(`Errors: ${errors}`);
  }

  // Display final balances
  await displayBalances(provider, luckyBuy, user);

  // Expected win rate
  const amountFloat = parseFloat(ethers.formatEther(commitAmount));
  const rewardFloat = parseFloat(ethers.formatEther(rewardAmount));
  const expectedWinRate = (amountFloat / rewardFloat) * 100;

  console.log(`\nExpected win rate: ${expectedWinRate.toFixed(2)}%`);
  console.log(`Actual win rate: ${((wins / numGames) * 100).toFixed(2)}%`);
}

// Run the simulation
playGames(SIMULATION_CONFIG.GAMES_TO_PLAY)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Simulation error:", error);
    process.exit(1);
  });
