#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== LuckyBuy Simulation Runner ===${NC}"
echo "This script will set up and run the LuckyBuy simulation"

# Check if Anvil is running
if ! nc -z localhost 8545 2>/dev/null; then
  echo -e "${YELLOW}Anvil does not appear to be running on port 8545${NC}"
  echo "Starting Anvil in a separate terminal (will run in background)..."
  anvil --silent > /dev/null 2>&1 &
  ANVIL_PID=$!
  echo "Anvil started with PID: $ANVIL_PID"
  
  # Give anvil time to start
  sleep 2
  echo "Waiting for Anvil to initialize..."
else
  echo "Anvil is already running on port 8545"
fi

# Build contracts
echo -e "\n${GREEN}Building contracts...${NC}"
npm run build

# Setup the environment
echo -e "\n${GREEN}Setting up the LuckyBuy environment...${NC}"
npm run setup:anvil

# Small pause
sleep 2

# Run the simulation
echo -e "\n${GREEN}Running the LuckyBuy simulation...${NC}"
npm run play:anvil

# Check if we started Anvil and kill it if needed
if [ ! -z "$ANVIL_PID" ]; then
  echo -e "\n${YELLOW}Shutting down Anvil instance (PID: $ANVIL_PID)${NC}"
  kill $ANVIL_PID
fi

echo -e "\n${GREEN}Simulation complete!${NC}" 