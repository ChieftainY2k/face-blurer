#!/bin/bash
# shellcheck disable=SC2086
set -e

# Define the number of GPUs and how many times to run the command per GPU

# Detect number of GPUS from nvisia-smi
GPUS=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
echo "Detected $GPUS GPUs"
RUNS_PER_GPU=4
echo "Will run $RUNS_PER_GPU times per GPU"

#for gpu in "${GPUS[@]}"; do
for ((gpu = 0; gpu < GPUS; gpu++)); do
  for ((i = 1; i <= RUNS_PER_GPU; i++)); do
    echo "Running on GPU $gpu ..."
    screen -S GPU-$gpu-$i ./process_single.sh $gpu
    #sleep 20
done
done
