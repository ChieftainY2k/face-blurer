#!/bin/bash
# shellcheck disable=SC2086

#set -e

. ./functions.sh

# check variables
if [ -z "$THOST" ]; then
  echo "THOST is not set"
  exit 1
fi

if [ -z "$TPORT" ]; then
  echo "TPORT is not set"
  exit 1
fi

if [ -z "$TUSER" ]; then
  echo "$TUSER is not set"
  exit 1
fi

LOCAL_SOURCE=${1:-"./input/video1.mp4"}
REMOTE_DEST="$TUSER@$THOST:/home/$TUSER/face-blurer/input/video1.mp4"

log_message "uploading '$LOCAL_SOURCE' to $THOST:$REMOTE_DEST"

# Loop until transfer is complete
while true; do
  rsync -avz --partial --info=progress2 --delete -e "ssh -p $TPORT" $LOCAL_SOURCE $REMOTE_DEST
  if [ $? -eq 0 ]; then
    #log_message "Transfer complete"
    break
  else
    log_message "transfer failed, retrying in 10 seconds..."
    countdown_seconds 10
  fi
done

log_message "upload complete"