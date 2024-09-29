#!/bin/bash
# shellcheck disable=SC2086

#set -x

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

function exec_remote() {
  echo "exec_remote: $@"
  ssh $TUSER@$THOST -p $TPORT $@
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo "ERROR: exec_remote: $@ failed with exit code $exit_code"
    exit $exit_code
  fi
}

# inject keys
cat ~/.ssh/id_rsa.pub | ssh $TUSER@$THOST -p $TPORT "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"

exec_remote nvidia-smi

exec_remote sudo apt-get install -y mc joe htop multitail docker-compose screen docker-buildx-plugin pydf iotop

exec_remote git clone https://github.com/ChieftainY2k/face-blurer.git

rsync -avz --partial --info=progress2 --delete -e "ssh -p $TPORT" ./input/video* $TUSER@$THOST:/home/$TUSER/face-blurer/input/