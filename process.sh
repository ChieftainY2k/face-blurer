#!/bin/bash
# shellcheck disable=SC2086
set -e

# Define the number of GPUs and how many times to run the command per GPU

# Detect number of GPUS from nvisia-smi
GPUS=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
#GPUS=(0 1)
RUNS_PER_GPU=4

#for gpu in "${GPUS[@]}"; do
for ((gpu = 0; gpu < GPUS; gpu++)); do
  for ((i = 1; i <= RUNS_PER_GPU; i++)); do
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
