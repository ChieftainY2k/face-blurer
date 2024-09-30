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
#cat ~/.ssh/id_rsa.pub | ssh $TUSER@$THOST -p $TPORT "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"

# inject keys if authorized_keys does not exist, in one line
echo "Injecting keys..."
cat ~/.ssh/id_rsa.pub | ssh $TUSER@$THOST -p $TPORT 'mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && cat >> ~/.ssh/authorized_keys'
echo "Keys injected."

exec_remote nvidia-smi
exec_remote free
exec_remote df -h

exec_remote sudo apt-get -y remove unattended-upgrades
exec_remote sudo apt-get install -y mc joe htop multitail docker-compose screen docker-buildx-plugin pydf iotop ffmpeg
exec_remote "curl https://gist.githubusercontent.com/ChieftainY2k/0a6fa487ac10658d667a0861f6c289ff/raw/e4573c108ebc32f5b06fc852506dce0d68b7a711/.screenrc > /home/$TUSER/.screenrc"

exec_remote "[ -d ~/face-blurer ] || git clone https://github.com/ChieftainY2k/face-blurer.git"
exec_remote "cd face-blurer && git pull"

#exec_remote "sudo curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg   && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |     sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list"
#exec_remote sudo apt-get update
#exec_remote sudo apt-get install -y nvidia-container-toolkit
#exec_remote sudo nvidia-ctk runtime configure --runtime=docker
#exec_remote sudo systemctl restart docker


exec_remote "cd face-blurer && docker build -f Dockerfile.gpu --progress=plain . -t blurer"

#rsync -avz --partial --info=progress2 --delete -e "ssh -p $TPORT" ./input/video1.mp4 $TUSER@$THOST:/home/$TUSER/face-blurer/input/

#exec_remote cd face-blurer \&\& \
#  docker run -v \$\(pwd\):/data linuxserver/ffmpeg -i "/data/input/video1.mp4" -fps_mode passthrough -q:v 0 -c:v png "/data/input/frame_%10d.png"

exec_remote "cd face-blurer && rm -f output/sample*"

exec_remote "cd face-blurer && docker run --rm --gpus all -v ./app:/app -v ./test-samples:/input:ro -v ./output:/output -v /tmp/blurer-cache/deepface:/root/.deepface -v /tmp/blurer-cache/root:/root/.cache blurer python blur_faces_slow.py"

