#!/bin/bash
# shellcheck disable=SC2086,SC2129
#set -e

. ./functions.sh

INFO_FILE="./output/metadata-worker-$MODE-$GPU-$INSTANCE"
echo "GPU=$GPU" > $INFO_FILE
echo "INSTANCE=$INSTANCE" >> $INFO_FILE
echo "DEBUG=$DEBUG" >> $INFO_FILE
echo "THRESHOLD=$THRESHOLD" >> $INFO_FILE
echo "MODE=$MODE" >> $INFO_FILE
echo "BLUR_EXTRA=$BLUR_EXTRA" >> $INFO_FILE
echo "BLUR_AHEAD=$BLUR_AHEAD" >> $INFO_FILE
echo "BLUR_BACK=$BLUR_BACK" >> $INFO_FILE

DONE_COUNT=1

while true; do

  echo -ne "\033k${MODE}/G${GPU}/${INSTANCE}(${DONE_COUNT})\033\\"

  log_message "Running , GPU=$GPU , INSTANCE=$INSTANCE , DEBUG=$DEBUG , THRESHOLD=$THRESHOLD , MODE=$MODE , BLUR_EXTRA=$BLUR_EXTRA , BLUR_AHEAD=$BLUR_AHEAD , BLUR_BACK=$BLUR_BACK"

  echo "STARTED=$(date +'%Y-%m-%d %H:%M:%S')" >> $INFO_FILE

  docker run --rm --gpus all \
    -e CUDA_VISIBLE_DEVICES=$GPU \
    -e DEBUG=$DEBUG \
    -e THRESHOLD=$THRESHOLD \
    -e MODE=$MODE \
    -e BLUR_EXTRA=$BLUR_EXTRA \
    -e BLUR_AHEAD=$BLUR_AHEAD \
    -e BLUR_BACK=$BLUR_BACK \
    -v ./app:/app \
    -v ./input:/input:ro \
    -v ./output:/output \
    -v /tmp/blurer-cache/deepface:/root/.deepface \
    -v /tmp/blurer-cache/root:/root/.cache \
    blurer python blur_faces_retinaface.py

  EXIT_CODE=$?
  if [ $EXIT_CODE -ne 0 ]; then
    echo -ne "\033k${MODE}/G${GPU}/${INSTANCE}(${DONE_COUNT})/ERR\033\\"
    echo "ERROR=$EXIT_CODE" >> $INFO_FILE
    # change window title to DONE on success, ERROR on error
    log_message 'Press [Enter] key to retry or [Ctrl+C] to exit...'
    read
  else
    echo -ne "\033k${MODE}/G${GPU}/${INSTANCE}(${DONE_COUNT})/OK\033\\"
    echo "DONE=1" >> $INFO_FILE
    echo "DONE_COUNT=$DONE_COUNT" >> $INFO_FILE
    DONE_COUNT=$((DONE_COUNT + 1))
    log_message "Processing finished successfully."
  fi
  echo "FINISHED=$(date +'%Y-%m-%d %H:%M:%S')" >> $INFO_FILE

  echo -ne "\033k${MODE}/G${GPU}/${INSTANCE}/${MODE}(${DONE_COUNT})/SLEEP\033\\"
  log_message "Sleeping..."
  countdown_seconds 120

done

#echo -ne "\033k${MODE}/G${GPU}/${INSTANCE}(${DONE_COUNT})/EXIT\033\\"
#log_message 'Press [Enter] key to continue...'
#read
