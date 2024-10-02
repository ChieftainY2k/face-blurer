#!/bin/bash
# shellcheck disable=SC2086,SC2129
set -e

log_message() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $@"
}

# Detect number of GPUS from nvisia-smi
GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
#GPU_COUNT=1
WORKER_COUNT=4
log_message "GPU_COUNT  = $GPU_COUNT , WORKER_COUNT = $WORKER_COUNT , DEBUG = $DEBUG , THRESHOLD = $THRESHOLD"
log_message "Press [Enter] key to continue..."
read

INFO_FILE="./output/metadata-run-$GPU-$INSTANCE.txt"
# save vars to local file
echo "DEBUG=$DEBUG" >> $INFO_FILE
echo "THRESHOLD=$THRESHOLD" >> $INFO_FILE

#screen -t "INFO" -- watch -c -n 3 "uptime; free; pydf; nvidia-smi; ls output/*.lock"

#for gpu in "${GPUS[@]}"; do
for ((gpu_idx = 0; gpu_idx < GPU_COUNT; gpu_idx++)); do
  for ((worker_idx = 0; worker_idx < WORKER_COUNT; worker_idx++)); do
    log_message "Running on GPU ${gpu_idx}/${GPU_COUNT} , worker ${worker_idx}/${WORKER_COUNT} , debug = $DEBUG , threshold = $THRESHOLD..."
    screen -t "GPU${gpu_idx}/${worker_idx}" -- ./worker.sh $gpu_idx $worker_idx $DEBUG $THRESHOLD
    sleep 20
  done
done
