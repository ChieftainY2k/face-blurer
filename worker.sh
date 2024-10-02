#!/bin/bash
# shellcheck disable=SC2086
#set -e

# get GPU from arg
GPU=$1
INSTANCE=$2
DEBUG=$3
THRESHOLD=$4

echo "Running on GPU $GPU , instance $INSTANCE , DEBUG=$DEBUG, THRESHOLD=$THRESHOLD ..."

# change window title
echo -ne "\033kGPU${GPU}[${INSTANCE}][RUN]\033\\"

docker run --rm --gpus all \
  -e CUDA_VISIBLE_DEVICES=$GPU \
  -e DEBUG=$DEBUG \
  -e THRESHOLD=$THRESHOLD \
  -v ./app:/app \
  -v ./input:/input:ro \
  -v ./output:/output \
  -v /tmp/blurer-cache/deepface:/root/.deepface \
  -v /tmp/blurer-cache/root:/root/.cache \
  blurer python blur_faces_retinaface.py

# change window title
echo -ne "\033kGPU${GPU}[${INSTANCE}][DONE]\033\\"

echo 'Press [Enter] key to continue...'
read
