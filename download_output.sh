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

#REMOTE_SOURCE={$1:-"vi*"}
REMOTE_SOURCE=${1:-"vi*"}
echo "Downloading $REMOTE_SOURCE from $THOST"

# Download videos
rsync -avz --partial --info=progress2 -e "ssh -p $TPORT" $TUSER@$THOST:/home/$TUSER/face-blurer/output/$REMOTE_SOURCE /tmp/output-$THOST/

# Download all
#rsync -avz --partial --info=progress2 -e "ssh -p $TPORT" $TUSER@$THOST:/home/$TUSER/face-blurer/output/ /tmp/output-$THOST/