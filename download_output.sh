#!/bin/bash
# shellcheck disable=SC2086

. ./functions.sh

# check variablews
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


#REMOTE_SOURCE={$1:-"vi*"}
REMOTE_SOURCE=${1:-"video"}
LOCAL_DEST="/tmp/output-$THOST"

mkdir -p $LOCAL_DEST
check_error "Failed to create directory $LOCAL_DEST"

# Loop until transfer is complete
while true; do
  while true; do
    log_message "downloading '$REMOTE_SOURCE' files from $THOST to $LOCAL_DEST"
    rsync -ravz --partial --info=progress2 -e "ssh -p $TPORT" $TUSER@$THOST:/home/$TUSER/face-blurer/output/$REMOTE_SOURCE $LOCAL_DEST
    if [ $? -eq 0 ]; then
      break
    else
      log_message "transfer failed, retrying in 10 seconds..."
      countdown_seconds 10
    fi
  done
  log_message "transfer complete, checking if there are more files to download... , press [Ctrl+C] to stop"
  countdown_seconds 30
done

log_message "download complete"

# Download videos


# Download all
#rsync -avz --partial --info=progress2 -e "ssh -p $TPORT" $TUSER@$THOST:/home/$TUSER/face-blurer/output/ /tmp/output-$THOST/