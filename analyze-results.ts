// analyze-results.ts
import * as fs from "fs";
import * as readline from "readline";

// Notes: The script resets after every 10,000 games because of limitations in foundry/my knowledge of foundry forge. But we can still use the treasuryBalanceChange to calculate the total amount of money lost/gained.

async function analyzeResults(filePath: string) {
  // Stats
  let totalGames = 0;
  let wins = 0;
  let losses = 0;
  let treasuryBalanceChange = 0;
  let amountWon = 0;
  let amountLost = 0;

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
    const commitAmount = record[5];
    const rewardAmount = record[6];
    const digest = record[7];
    const signature = record[8];
    const odds = record[9];
    const won = record[10] === "true" ? true : false;
    const balanceChange = parseInt(record[11], 0);
    const feeAmount = parseInt(record[12], 0);
    //const treasuryBalance = record[13];

    if (isNaN(balanceChange)) {
      console.log(`Invalid balance change value in line: ${line}`);
      console.log(balanceChange);
      console.log(commitId);
      console.log(user);
      continue;
    }

    if (won) {
      wins++;
      amountWon += balanceChange;
    } else {
      losses++;
      amountLost += balanceChange;
    }
  }

  const winPercentage = (wins / totalGames) * 100;
  const lossPercentage = (losses / totalGames) * 100;

  console.log(`Total games: ${totalGames}`);
  console.log(`Wins: ${wins}`);
  console.log(`Losses: ${losses}`);
  console.log(`Win Rate: ${winPercentage.toFixed(4)}%`);
  console.log(`Loss Rate: ${lossPercentage.toFixed(4)}%`);

  console.log(`Treasury Balance Change: ${treasuryBalanceChange}`);
  console.log(`Amount Won: ${amountWon}`);
  console.log(`Amount Lost: ${amountLost}`);
  console.log(`Net Profit/Loss: ${amountLost - amountWon}`);
}

// Run with: npx ts-node analyze-results.ts [filepath]
const filePath = process.argv[2] || "./simulations/combined_results.csv";
analyzeResults(filePath).catch((err) => {
  console.error("Error processing file:", err);
});
