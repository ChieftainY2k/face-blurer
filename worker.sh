#!/bin/bash
# shellcheck disable=SC2086
#set -e

# get GPU from arg
GPU=$1
INSTANCE=$1

echo "Running on GPU $GPU , instance $INSTANCE ..."

#screen -X "title" "GPU $gpu/$i [RUNNING]"

docker run --rm --gpus all \
  -e CUDA_VISIBLE_DEVICES=$GPU \
  -e DEBUG=1 \
  -v ./app:/app \
  -v ./input:/input:ro \
  -v ./output:/output \
  -v /tmp/blurer-cache/deepface:/root/.deepface \
  -v /tmp/blurer-cache/root:/root/.cache \
  blurer python blur_faces_slow.py

#screen -X "title" "GPU $gpu/$i [DONE]"

echo 'Press [Enter] key to continue...'
read

