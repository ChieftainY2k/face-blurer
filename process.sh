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
    echo "Running on GPU $gpu, run $i"
    screen docker run --rm --gpus all \
      -e CUDA_VISIBLE_DEVICES=$gpu \
      -e DEBUG=1 \
      -v ./app:/app \
      -v ./input:/input:ro \
      -v ./output:/output \
      -v /tmp/blurer-cache/deepface:/root/.deepface \
      -v /tmp/blurer-cache/root:/root/.cache \
      blurer python blur_faces_slow.py
  done
done
