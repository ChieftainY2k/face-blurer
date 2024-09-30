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

LOCAL_SOURCE=${1:-"./input/video1.mp4"}
rsync -avz --partial --info=progress2 --delete -e "ssh -p $TPORT" $LOCAL_SOURCE $TUSER@$THOST:/home/$TUSER/face-blurer/input/video.mp4