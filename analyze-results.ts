// analyze-results.ts
import * as fs from "fs";
import * as readline from "readline";
import { ethers } from "ethers";

// Notes: The script resets after every 10,000 games because of limitations in foundry/my knowledge of foundry forge. But we can still use the treasuryBalanceChange to calculate the total amount of money lost/gained.

async function analyzeResults(filePath: string) {
  // Stats
  let totalGames = 0;
  let wins = 0;
  let losses = 0;
  let fees = ethers.parseUnits("0", "wei");
  let amountWon = ethers.parseUnits("0", "wei");
  let amountLost = ethers.parseUnits("0", "wei");
  let treasuryBalance = ethers.parseUnits("0", "wei");
  let lowWaterMark = ethers.parseUnits("0", "wei");
  let highWaterMark = ethers.parseUnits("0", "wei");

  // Create a readline interface to read the file line by line
  const fileStream = fs.createReadStream(filePath);
  const rl = readline.createInterface({
    input: fileStream,
    crlfDelay: Infinity,
  });

  // Process each line
  for await (const line of rl) {
    totalGames++;

    const record = line.split(",");
    const commitId = record[0];
    const user = record[1];
    const seed = record[2];
    const counter = record[3];
    const orderHash = record[4];
    const commitAmount = ethers.parseUnits(record[5], "wei");
    const rewardAmount = ethers.parseUnits(record[6], "wei");
    const digest = record[7];
    const signature = record[8];
    const odds = record[9];
    const won = record[10] === "true" ? true : false;
    const balanceChange = ethers.parseUnits(record[11], "wei");
    const feeAmount = ethers.parseUnits(record[12], "wei");

    if (won) {
      wins++;
      amountWon += rewardAmount - commitAmount;
      treasuryBalance -= rewardAmount - commitAmount;
    } else {
      losses++;
      amountLost += commitAmount;
      treasuryBalance += commitAmount;
    }

    fees += feeAmount;

    // Update water marks
    if (totalGames === 1) {
      // Initialize high and low water marks with the first balance
      highWaterMark = treasuryBalance;
      lowWaterMark = treasuryBalance;
    } else {
      // Update high water mark
      if (treasuryBalance > highWaterMark) {
        highWaterMark = treasuryBalance;
      }

      // Update low water mark
      if (treasuryBalance < lowWaterMark) {
        lowWaterMark = treasuryBalance;
      }
    }
  }

  const winPercentage = (wins / totalGames) * 100;
  const lossPercentage = (losses / totalGames) * 100;

  console.log(`Total games: ${totalGames}`);
  console.log(`Wins: ${wins}`);
  console.log(`Losses: ${losses}`);
  console.log(`Win Rate: ${winPercentage.toFixed(4)}%`);
  console.log(`Loss Rate: ${lossPercentage.toFixed(4)}%`);

  console.log(`Amount Won (Paid to User): ${ethers.formatEther(amountWon)}`);
  console.log(
    `Amount Lost (Paid to Treasury): ${ethers.formatEther(amountLost)}`
  );
  console.log(`Treasury Change: ${ethers.formatEther(amountLost - amountWon)}`);
  console.log(`Fees: ${ethers.formatEther(fees)}`);
  console.log(`Final Treasury Balance: ${ethers.formatEther(treasuryBalance)}`);
  console.log(`Treasury High Water Mark: ${ethers.formatEther(highWaterMark)}`);
  console.log(`Treasury Low Water Mark: ${ethers.formatEther(lowWaterMark)}`);
}

// Run with: npx ts-node analyze-results.ts [filepath]
const filePath = process.argv[2] || "./simulations/combined_results.csv";
analyzeResults(filePath).catch((err) => {
  console.error("Error processing file:", err);
});
