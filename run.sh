#!/bin/bash
# shellcheck disable=SC2086,SC2129
#set -e

. ./functions.sh

# check if you are inside screen session
if [ -z "$STY" ]; then
  log_message "Please run this script inside a screen session"
  exit 1
fi

log_message "DEBUG=$DEBUG , THRESHOLD=$THRESHOLD , BLUR_EXTRA=$BLUR_EXTRA , BLUR_AHEAD=$BLUR_AHEAD , BLUR_BACK=$BLUR_BACK"

PROVISION_INFO_FILE="../metadata-provision"
log_message "Waiting for docker builds to finish..."
while ! grep -q "DOCKER_BUILD_FINISHED=" "$PROVISION_INFO_FILE"; do
  countdown_seconds 10
done
log_message "Docker build finished"

log_message "Sleeping for a while..."
countdown_seconds 10

log_message "Running pass 1"
MODE=pass1 DEBUG=$DEBUG WORKERS=6 BLUR_EXTRA=$BLUR_EXTRA BLUR_AHEAD=$BLUR_AHEAD BLUR_BACK=$BLUR_BACK ./run_pass.sh
log_message "Sleeping for a while..."
countdown_seconds 10

log_message "Running pass 2"
MODE=pass2 DEBUG=$DEBUG GPUS=1 WORKERS=7 BLUR_EXTRA=$BLUR_EXTRA BLUR_AHEAD=$BLUR_AHEAD BLUR_BACK=$BLUR_BACK ./run_pass.sh
