#!/bin/bash
# shellcheck disable=SC2086,SC2129
set -e

log_message() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $@"
}

# check if you are inside screen session
if [ -z "$STY" ]; then
  log_message "Please run this script inside a screen session"
  exit 1
fi

log_message "GPUS=$GPUS , WORKERS=$WORKERS , DEBUG=$DEBUG , THRESHOLD=$THRESHOLD , MODE=$MODE, BLUR_EXTRA=$BLUR_EXTRA , BLUR_AHEAD=$BLUR_AHEAD , BLUR_BACK=$BLUR_BACK"
log_message "Sleeping for a while..."
sleep 15

log_message "Running pass 1"
WORKERS=6 MODE=pass1 ./run_pass.sh
log_message "Sleeping for a while..."
sleep 15

log_message "Running pass 2"
GPUS=1 WORKERS=7 MODE=pass2 ./run_pass.sh
