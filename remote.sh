#!/bin/bash
# shellcheck disable=SC2086

# check variablews
if [ -z "$THOST" ]; then
  echo "THOST is not set"
  exit 1
fi

if [ -z "$TPORT" ]; then
  echo "TPORT is not set"
  exit 1
fi

# exec a remote command
ssh user@$THOST -p $TPORT "$@"
