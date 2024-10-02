#!/bin/bash
# shellcheck disable=SC2086,SC2129
#set -e

log_message() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $@"
}

# get GPU from arg
GPU=$1
INSTANCE=$2
DEBUG=$3
THRESHOLD=$4

log_message "Running on GPU $GPU , instance $INSTANCE , DEBUG=$DEBUG, THRESHOLD=$THRESHOLD ..."

# change window title
echo -ne "\033kGPU${GPU}/${INSTANCE}(WORK)\033\\"

INFO_FILE="./output/metadata-worker-$GPU-$INSTANCE"
# save vars to local file
echo "GPU=$GPU" > $INFO_FILE
echo "INSTANCE=$INSTANCE" >> $INFO_FILE
echo "DEBUG=$DEBUG" >> $INFO_FILE
echo "THRESHOLD=$THRESHOLD" >> $INFO_FILE
echo "STARTED=$(date +'%Y-%m-%d %H:%M:%S')" >> $INFO_FILE

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

# change window title to DONE on success, ERROR on error
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo -ne "\033kGPU${GPU}/${INSTANCE}(ERROR)\033\\"
  echo "ERROR=$EXIT_CODE" >> $INFO_FILE
else
  echo -ne "\033kGPU${GPU}/${INSTANCE}(DONE)\033\\"
  echo "FINISHED=$(date +'%Y-%m-%d %H:%M:%S')" >> $INFO_FILE
fi

log_message 'Press [Enter] key to continue...'
read
