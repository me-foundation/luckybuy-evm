#!/bin/bash

# Run multiple simulations in parallel
for i in {1..100}; do
  echo "Starting simulation with SEED=$i"
  SEED=$i forge test --match-test testSimulatePlay -vv --gas-limit 9999999999999999999 > "./simulations/simulation_$i.log" 2>&1 &
  
  # Optional: Add a small delay to avoid overwhelming the system
  sleep 0.5
  
  # Optional: Limit max parallel processes (adjust number as needed)
  # This example limits to 5 parallel processes
  if (( i % 10 == 0 )); then
    echo "Waiting for batch to complete..."
    wait
  fi
done

# Wait for all remaining background processes to finish
wait

cat simulations/simulation_*.csv > simulations/combined_results.csv

echo "All simulations completed!"
