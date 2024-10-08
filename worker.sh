#!/bin/bash
# shellcheck disable=SC2086,SC2129
#set -e

. ./functions.sh

INFO_FILE="./output/metadata-worker-$MODE-$GPU-$INSTANCE"
echo "GPU=$GPU" >$INFO_FILE
echo "INSTANCE=$INSTANCE" >>$INFO_FILE
echo "DEBUG=$DEBUG" >>$INFO_FILE
echo "THRESHOLD=$THRESHOLD" >>$INFO_FILE
echo "MODE=$MODE" >>$INFO_FILE
echo "BLUR_EXTRA=$BLUR_EXTRA" >>$INFO_FILE
echo "BLUR_AHEAD=$BLUR_AHEAD" >>$INFO_FILE
echo "BLUR_BACK=$BLUR_BACK" >>$INFO_FILE

LOOP_COUNT=0

while true; do

  LOOP_COUNT=$((LOOP_COUNT + 1))
  echo "LOOP_COUNT=$LOOP_COUNT" >>$INFO_FILE

  set_sceen_name "${MODE}/G${GPU}/${INSTANCE}(${LOOP_COUNT})"

  log_message "Running , GPU=$GPU , INSTANCE=$INSTANCE , DEBUG=$DEBUG , THRESHOLD=$THRESHOLD , MODE=$MODE , BLUR_EXTRA=$BLUR_EXTRA , BLUR_AHEAD=$BLUR_AHEAD , BLUR_BACK=$BLUR_BACK"

  echo "STARTED=$(date +'%Y-%m-%d %H:%M:%S')" >>$INFO_FILE

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
    log_message "Error occurred. Exit code: $EXIT_CODE"
    set_sceen_name "${MODE}/G${GPU}/${INSTANCE}(${LOOP_COUNT})/ERR"
    echo "ERROR=$EXIT_CODE" >>$INFO_FILE
    #    log_message 'Press [Enter] key to retry or [Ctrl+C] to exit...'
    #    read
    #    echo -ne "\033k${MODE}/G${GPU}/${INSTANCE}/${MODE}(${LOOP_COUNT})/S\033\\"
    log_message "Sleeping..."
    countdown_seconds 600

  else
    log_message "Processing finished successfully."
    set_sceen_name "${MODE}/G${GPU}/${INSTANCE}(${LOOP_COUNT})/OK"
    echo "DONE=1" >>$INFO_FILE
    #    echo -ne "\033k${MODE}/G${GPU}/${INSTANCE}/${MODE}(${LOOP_COUNT})/SLEEP\033\\"
    log_message "Sleeping..."
    countdown_seconds 120

  fi
  
  echo "FINISHED=$(date +'%Y-%m-%d %H:%M:%S')" >>$INFO_FILE

done

#echo -ne "\033k${MODE}/G${GPU}/${INSTANCE}(${LOOP_COUNT})/EXIT\033\\"
#log_message 'Press [Enter] key to continue...'
#read
