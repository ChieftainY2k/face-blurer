#!/bin/bash
# shellcheck disable=SC2086,SC2129
set -e

. ./functions.sh

# check if you are inside screen session
if [ -z "$STY" ]; then
  log_message "Please run this script inside a screen session"
  exit 1
fi

log_message "DEBUG=$DEBUG , THRESHOLD=$THRESHOLD , MODE=$MODE, BLUR_EXTRA=$BLUR_EXTRA , BLUR_AHEAD=$BLUR_AHEAD , BLUR_BACK=$BLUR_BACK"

PROVISION_INFO_FILE="../metadata-provision"
log_message "Waiting for provision to finish..."
while ! grep -q "FINISHED=" "$PROVISION_INFO_FILE"; do
  countdown_seconds 10
done
log_message "Provision finished, continuing..."

log_message "Sleeping for a while..."
countdown_seconds 10

log_message "Running pass 1"
WORKERS=6 MODE=pass1 ./run_pass.sh
log_message "Sleeping for a while..."
countdown_seconds 10

log_message "Running pass 2"
GPUS=1 WORKERS=7 MODE=pass2 ./run_pass.sh
