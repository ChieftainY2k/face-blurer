#!/bin/bash
# shellcheck disable=SC2086

set -e

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

log_message() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')]: $@"
}

#REMOTE_SOURCE={$1:-"vi*"}
REMOTE_SOURCE=${1:-"vi*"}
LOCAL_DEST="/tmp/output-$THOST"
#echo "Downloading '$REMOTE_SOURCE' files from $THOST"
log_message "Downloading '$REMOTE_SOURCE' files from $THOST to $LOCAL_DEST"

# Loop until transfer is complete
while true; do
  rsync -avz --partial --info=progress2 -e "ssh -p $TPORT" $TUSER@$THOST:/home/$TUSER/face-blurer/output/$REMOTE_SOURCE $LOCAL_DEST
  if [ $? -eq 0 ]; then
    break
  else
    log_message "Transfer failed, retrying in 10 seconds..."
    sleep 10
  fi
done

log_message "Download complete"

# Download videos


# Download all
#rsync -avz --partial --info=progress2 -e "ssh -p $TPORT" $TUSER@$THOST:/home/$TUSER/face-blurer/output/ /tmp/output-$THOST/