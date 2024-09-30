#!/bin/bash
# shellcheck disable=SC2086
#set -e

# get GPU from arg
GPU=$1
INSTANCE=$1

screen -X title "GPU $GPU/$INSTANCE"

echo "Running on GPU $GPU , instance $INSTANCE ..."
docker run --rm --gpus all \
  -e CUDA_VISIBLE_DEVICES=$GPU \
  -e DEBUG=1 \
  -v ./app:/app \
  -v ./input:/input:ro \
  -v ./output:/output \
  -v /tmp/blurer-cache/deepface:/root/.deepface \
  -v /tmp/blurer-cache/root:/root/.cache \
  blurer python blur_faces_slow.py

echo 'Press [Enter] key to continue...'
read

