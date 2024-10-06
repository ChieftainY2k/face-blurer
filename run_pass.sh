#!/bin/bash
# shellcheck disable=SC2086,SC2129
set -e

. ./functions.sh

# check if you are inside screen session
if [ -z "$STY" ]; then
  log_message "Please run this script inside a screen session"
  exit 1
fi

# Detect number of GPUS from nvisia-smi
if [ -z "$GPUS" ]; then
  GPUS=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
fi
WORKERS=${WORKERS:-6}

log_message "GPUS=$GPUS , WORKERS=$WORKERS , DEBUG=$DEBUG , THRESHOLD=$THRESHOLD , MODE=$MODE, BLUR_EXTRA=$BLUR_EXTRA , BLUR_AHEAD=$BLUR_AHEAD , BLUR_BACK=$BLUR_BACK"
#log_message "Press [Enter] key to continue..."
#read
log_message "Sleeping for a while..."
countdown_seconds 10

INFO_FILE="./output/metadata-run-$MODE"
# save vars to local file
echo "DEBUG=$DEBUG" > $INFO_FILE
echo "THRESHOLD=$THRESHOLD" >> $INFO_FILE
echo "MODE=$MODE" >> $INFO_FILE
echo "BLUR_EXTRA=$BLUR_EXTRA" >> $INFO_FILE
echo "BLUR_AHEAD=$BLUR_AHEAD" >> $INFO_FILE
echo "BLUR_BACK=$BLUR_BACK" >> $INFO_FILE
echo "STARTED=$(date +'%Y-%m-%d %H:%M:%S')" >> $INFO_FILE

#screen -t "INFO" -- watch -c -n 3 "uptime; free; pydf; nvidia-smi; ls output/*.lock"

#for gpu in "${GPUS[@]}"; do
for ((gpu_idx = 0; gpu_idx < GPUS; gpu_idx++)); do
  for ((worker_idx = 0; worker_idx < WORKERS; worker_idx++)); do
    log_message "Running on GPU ${gpu_idx}/${GPUS} , worker ${worker_idx}/${WORKERS} , DEBUG=$DEBUG , THRESHOLD=$THRESHOLD , MODE=$MODE ..."
    #screen -t "GPU${gpu_idx}/${worker_idx}" -- ./worker.sh "$gpu_idx" "$worker_idx" "$DEBUG" "$THRESHOLD" "$MODE"
    screen -t "$MODE/G${gpu_idx}/${worker_idx}" -- bash -c "GPU=${gpu_idx} INSTANCE=${worker_idx} DEBUG=${DEBUG} THRESHOLD=${THRESHOLD} MODE=${MODE} BLUR_EXTRA=$BLUR_EXTRA BLUR_AHEAD=$BLUR_AHEAD BLUR_BACK=$BLUR_BACK ./worker.sh"
    countdown_seconds 30
  done
done
