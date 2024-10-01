#!/bin/bash
# shellcheck disable=SC2086
set -e

# Detect number of GPUS from nvisia-smi
GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
echo "Detected $GPU_COUNT GPUs"
WORKER_COUNT=4
echo "Will run $WORKER_COUNT times per GPU"

#screen -t "INFO" -- watch -c -n 3 "uptime; free; pydf; nvidia-smi; ls output/*.lock"

#for gpu in "${GPUS[@]}"; do
for ((gpu_idx = 0; gpu_idx < GPU_COUNT; gpu_idx++)); do
  for ((worker_idx = 0; worker_idx < WORKER_COUNT; worker_idx++)); do
    echo "Running on GPU ${gpu_idx}/${GPU_COUNT} , worker ${worker_idx}/${WORKER_COUNT} ..."
    screen -t "GPU${gpu_idx}[${worker_idx}]" -- ./worker.sh $gpu_idx $worker_idx
    sleep 20
  done
done
