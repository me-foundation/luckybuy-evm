#!/bin/bash

# Run multiple simulations in parallel
rm -rf ./simulations/*

wait

for i in {1..1000}; do 
  echo "Starting simulation with SEED=$i"
  SEED=$i forge test --match-test testSimulatePlay -vv --gas-limit 9999999999999999999 > "./simulations/simulation_$i.log" 2>&1 &
  
  
  
  # limits to 10 parallel processes
  if (( i % 10 == 0 )); then
    echo "Waiting for batch to complete..."
    wait
  fi
done

# Wait for all remaining background processes to finish
wait

cat simulations/simulation_*.csv > simulations/combined_results.csv

wait

echo "All simulations completed!"
