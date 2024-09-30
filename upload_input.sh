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

INPUT={$1:-"./input/vi*"}
rsync -avz --partial --info=progress2 --delete -e "ssh -p $TPORT" $INPUT $TUSER@$THOST:/home/$TUSER/face-blurer/input/