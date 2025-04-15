1. Start `anvil`
2. We need 3 keys, deployer, cosigner, user
3. Cosigner will perform the fulfillments

// 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
// 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
// 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a

4. Simple loop, use cosigner-lib to create commits and fulfill them through numerous test scenarios.

## Anvil Simulation Tools

This directory contains TypeScript tools for deploying and interacting with the LuckyBuy contract on a local Anvil instance.

### Scripts

- **1.setupAnvilEnvironment.ts**: Deploys the LuckyBuy contract to a local Anvil instance
- **2.playLuckyBuy.ts**: Runs multiple games (commits and fulfills) to simulate real usage
- **commitAndFulfill.ts**: Simple example of creating a commit and fulfilling it
- **contractUtils.ts**: Shared utilities for interacting with the contract

### Deployment Instructions

To deploy the LuckyBuy contract to your local Anvil instance:

1. Start an Anvil node in a separate terminal:

   ```bash
   anvil
   ```

2. Build the contracts with Foundry:

   ```bash
   forge build
   ```

3. Run the setup script:
   ```bash
   npm run setup:anvil
   ```

This will:

- Deploy the LuckyBuy contract with 0 protocol fee
- Fund it with 10 ETH
- Add the cosigner to the contract
- Save deployment information to `anvil-simulations/deployment.json`

### Playing LuckyBuy Games

After setting up the environment, you can run a simulation that plays multiple LuckyBuy games:

```bash
npm run play:anvil
```

This script:

1. Uses the MagicSigner class from cosigner-lib for proper EIP-712 signature generation
2. Plays multiple games with configurable reward and commit amounts
3. Each game creates a commit and then fulfills it
4. Shows detailed statistics about wins/losses
5. Tracks balances throughout the simulation

You can configure the game parameters in your `.env` file:

```
GAMES_TO_PLAY=3        # Number of games to play
REWARD_AMOUNT=1.0      # Reward amount in ETH
COMMIT_AMOUNT=0.5      # Commit amount in ETH
DELAY_BETWEEN_GAMES=1000  # Delay in ms between games
```

### Simple Commit and Fulfill Example

You can also run a simple example that creates a single commit and fulfills it:

```bash
npm run commit:anvil
```

This example:

1. Creates a commit with a 50% chance of winning (0.5 ETH commit for a 1.0 ETH reward)
2. Gets the cosigner to sign the commitment
3. Fulfills the commit
4. Displays the results

### Configuration

All scripts use environment variables for configuration with sensible defaults.
You can customize them by creating a `.env` file in the root directory:

```
# Anvil Simulation Configuration
ANVIL_RPC_URL=http://localhost:8545
ANVIL_CHAIN_ID=31337

# Contract Settings
PROTOCOL_FEE=0
FUNDING_AMOUNT=10

# Game Settings
GAMES_TO_PLAY=3
REWARD_AMOUNT=1.0
COMMIT_AMOUNT=0.5
```

See `.env.example` for a full list of configurable options.

### Optimization Options

The simulation can be customized to run much faster:

```
# Speed and Performance Settings
DELAY_BETWEEN_GAMES=0    # Set to 0 for fastest simulation (no delays)
VERBOSE=false            # Set to false to minimize console output
BATCH_SIZE=5             # Number of games to batch together (0 to disable batching)
```

In batch mode, the simulation will:

1. Create multiple commit transactions in sequence
2. Then fulfill them all one by one
3. This reduces the overhead of displaying detailed information for each step

Performance benchmarks on a local Anvil instance:

- Sequential mode (BATCH_SIZE=0): ~0.3-0.5s per game
- Batch mode (BATCH_SIZE=5): ~0.15-0.3s per game

The simulation will automatically show performance statistics when it completes.

4. Run the game simulation:
   ```bash
   npm run play:anvil
   ```

If you encounter any issues with the game simulation, you can use the retry command that will automatically restart the script on failure:

```bash
npm run play:retry
```

### Running a Complete Simulation

If you want to run a complete simulation from scratch, including starting Anvil, deploying the contract, and running games, you can use the convenience script:

```bash
chmod +x anvil-simulations/runSimulation.sh  # Make executable (first time only)
npm run simulate
```

This script will:

1. Check if Anvil is running and start it if needed
2. Build the contracts with Forge
3. Deploy the contracts to Anvil
4. Run the LuckyBuy simulation
5. Clean up by shutting down Anvil if it was started by the script

It's a great way to quickly demo the LuckyBuy contract in action.
