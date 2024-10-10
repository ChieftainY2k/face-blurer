#!/bin/bash
# shellcheck disable=SC2086

#set -e

. ./functions.sh

check_required_vars

LOCAL_SOURCE=${1:-"./input/video1.mp4"}
REMOTE_DEST="$TUSER@$THOST:/home/$TUSER/face-blurer/input/video1.mp4"

LOOP_COUNT=0

INFO_FILE_UPLOAD="./metadata-upload"
exec_remote "echo \"STARTED=$(date +'%Y-%m-%d %H:%M:%S')\" >> ${INFO_FILE_UPLOAD}"
exec_remote "echo \"LOCAL_FILENAME=$LOCAL_SOURCE\" >> ${INFO_FILE_UPLOAD}"

# Loop until transfer is complete
while true; do
  LOOP_COUNT=$((LOOP_COUNT + 1))
  log_message "uploading '$LOCAL_SOURCE' to $THOST:$REMOTE_DEST , attempt $LOOP_COUNT"
  set_sceen_name "Upload($LOOP_COUNT)/uploading"
  rsync -avz --partial --info=progress2 --delete -e "ssh -p $TPORT" "$LOCAL_SOURCE" $REMOTE_DEST
  if [ $? -eq 0 ]; then
    #log_message "Transfer complete"
    #set_sceen_name "Upload($LOOP_COUNT)/DONE"
    break
  else
    log_message "transfer failed, retrying in 10 seconds..."
    set_sceen_name "Upload($LOOP_COUNT)/RETRY"
    countdown_seconds 10
  fi
done

log_message "upload complete"
exec_remote "echo \"FINISHED=$(date +'%Y-%m-%d %H:%M:%S')\" >> ${INFO_FILE_UPLOAD}"
set_sceen_name "Upload($LOOP_COUNT)/DONE"
read -p "Press ENTER to continue"
