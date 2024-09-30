#!/bin/bash
# shellcheck disable=SC2086
set -e

# Detect number of GPUS from nvisia-smi
GPUS=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
echo "Detected $GPUS GPUs"
RUNS_PER_GPU=4
echo "Will run $RUNS_PER_GPU times per GPU"

screen -t "INFO" -- watch -c -n 3 "uptime; free; pydf; nvidia-smi; ls output/*.lock"

#for gpu in "${GPUS[@]}"; do
for ((gpu = 0; gpu < GPUS; gpu++)); do
  for ((i = 0; i < RUNS_PER_GPU; i++)); do
    echo "Running on GPU $gpu , worker $i ..."
    screen -t "GPU $gpu/$i" -- ./worker.sh $gpu $i
    sleep 20
  done
done
