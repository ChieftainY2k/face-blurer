#!/bin/bash

# Exit immediately on error
set -euo pipefail

# Required variables
required_vars=("THOST" "TPORT" "TUSER")

# Check if required variables are set
for var in "${required_vars[@]}"; do
  if [ -z "${!var:-}" ]; then
    echo "$var is not set"
    exit 1
  fi
done

# Function to execute commands remotely
exec_remote() {
  local exit_code=$?
  echo "exec_remote: $@"
  ssh "$TUSER@$THOST" -p "$TPORT" "$@"
  if [ $exit_code -ne 0 ]; then
    echo "ERROR: exec_remote: $@ failed with exit code $exit_code"
    exit $exit_code
  fi
}

# Log start time
log_message() {
  local message="$1"
  log_message_local "$message"
  exec_remote "echo \"[$(date '+%Y-%m-%d %H:%M:%S')] $message\" >> /home/user/provision-log.txt"
}

# Log start time
log_message_local() {
  local message="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message"
}

# Inject SSH keys
echo "Injecting keys..."
ssh "$TUSER@$THOST" -p "$TPORT" 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
cat ~/.ssh/id_rsa.pub | ssh "$TUSER@$THOST" -p "$TPORT" 'cat >> ~/.ssh/authorized_keys'
echo "Keys injected."

log_message "started"

# set timezone to warsaw
exec_remote "sudo timedatectl set-timezone Europe/Warsaw"

# Remote system checks
exec_remote nvidia-smi
exec_remote free
exec_remote df -h

# Remove and install packages
log_message "packages update starting"
exec_remote "sudo apt-get -y remove unattended-upgrades"
exec_remote "sudo apt-get install -y mc joe htop multitail docker-compose screen docker-buildx-plugin pydf iotop ffmpeg"
log_message "packages update finished"

# Download .screenrc configuration
exec_remote "curl -s https://gist.githubusercontent.com/ChieftainY2k/0a6fa487ac10658d667a0861f6c289ff/raw/e4573c108ebc32f5b06fc852506dce0d68b7a711/.screenrc > /home/$TUSER/.screenrc"

# Clone or update the repository
log_message "repo clone starting"
exec_remote "[ -d ~/face-blurer ] || git clone https://github.com/ChieftainY2k/face-blurer.git"
exec_remote "cd face-blurer && git pull"
log_message "repo clone finished"

# Run driver check script
log_message "drivers check started"
exec_remote "cd face-blurer && sudo ./drivers_reinstall.sh"
log_message "drivers check finished"

# Build Docker image
log_message "docker image build starting"
exec_remote "cd face-blurer && docker build -f Dockerfile.gpu --progress=plain . -t blurer"
log_message "docker image build finished"

# Uncomment if needed for rsync and Docker execution
# rsync -avz --partial --info=progress2 --delete -e "ssh -p $TPORT" ./input/video1.mp4 $TUSER@$THOST:/home/$TUSER/face-blurer/input/
# exec_remote "cd face-blurer && docker run -v \$(pwd):/data linuxserver/ffmpeg -i \"/data/input/video1.mp4\" -fps_mode passthrough -q:v 0 -c:v png \"/data/input/frame_%10d.png\""
# exec_remote "cd face-blurer && rm -f output/sample*"
# exec_remote "cd face-blurer && docker run --rm --gpus all -v ./app:/app -v ./test-samples:/input:ro -v ./output:/output -v /tmp/blurer-cache/deepface:/root/.deepface -v /tmp/blurer-cache/root:/root/.cache blurer python blur_faces_retinaface.py"

log_message "rebooting server..."
#exec_remote "sudo reboot"
exec_remote "sudo bash -c \"sleep 3 && sudo reboot\" &"
log_message_local "waiting..."
sleep 10
# wait until server is reabooted, check every 1 second
while ! exec_remote "uptime"; do
#  echo -n "."
  sleep 1
done
sleep 20
log_message "server is up"
exec_remote nvidia-smi


log_message "provisioning finished"

##!/bin/bash
## shellcheck disable=SC2086
#
#set -e
#
## check variablews
#if [ -z "$THOST" ]; then
#  echo "THOST is not set"
#  exit 1
#fi
#
#if [ -z "$TPORT" ]; then
#  echo "TPORT is not set"
#  exit 1
#fi
#
#if [ -z "$TUSER" ]; then
#  echo "$TUSER is not set"
#  exit 1
#fi
#
#function exec_remote() {
#  echo "exec_remote: $@"
#  ssh $TUSER@$THOST -p $TPORT $@
#  local exit_code=$?
#  if [ $exit_code -ne 0 ]; then
#    echo "ERROR: exec_remote: $@ failed with exit code $exit_code"
#    exit $exit_code
#  fi
#}
#
## inject keys
#echo "Injecting keys..."
#cat ~/.ssh/id_rsa.pub | ssh $TUSER@$THOST -p $TPORT 'mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && cat >> ~/.ssh/authorized_keys'
#echo "Keys injected."
#
## show date t YYYY-mm-dd HH:MM:SS
#exec_remote "echo \"[$(date "+%Y-%m-%d %H:%M:%S")] started\" >> /home/user/provision-log.txt"
#
#exec_remote nvidia-smi
#exec_remote free
#exec_remote df -h
#
#exec_remote "echo \"[$(date "+%Y-%m-%d %H:%M:%S")] packages update starting\" >> /home/user/provision-log.txt"
#exec_remote sudo apt-get -y remove unattended-upgrades
#exec_remote sudo apt-get install -y mc joe htop multitail docker-compose screen docker-buildx-plugin pydf iotop ffmpeg
#exec_remote "echo \"[$(date "+%Y-%m-%d %H:%M:%S")] packages update finished\" >> /home/user/provision-log.txt"
#
#exec_remote "curl https://gist.githubusercontent.com/ChieftainY2k/0a6fa487ac10658d667a0861f6c289ff/raw/e4573c108ebc32f5b06fc852506dce0d68b7a711/.screenrc > /home/$TUSER/.screenrc"
#
#
#exec_remote "echo \"[$(date "+%Y-%m-%d %H:%M:%S")] repo clone starting\" >> /home/user/provision-log.txt"
#exec_remote "[ -d ~/face-blurer ] || git clone https://github.com/ChieftainY2k/face-blurer.git"
#exec_remote "cd face-blurer && git pull"
#exec_remote "echo \"[$(date "+%Y-%m-%d %H:%M:%S")] repo clone finished\" >> /home/user/provision-log.txt"
#
#exec_remote "echo \"[$(date "+%Y-%m-%d %H:%M:%S")] docker image build starting\" >> /home/user/provision-log.txt"
#exec_remote "cd face-blurer && docker build -f Dockerfile.gpu --progress=plain . -t blurer"
#exec_remote "echo \"[$(date "+%Y-%m-%d %H:%M:%S")] docker image build finished\" >> /home/user/provision-log.txt"
#
#exec_remote "echo \"[$(date "+%Y-%m-%d %H:%M:%S")] drivers check started\" >> /home/user/provision-log.txt"
#exec_remote "cd face-blurer && ./drivers_reinstall.sh"
#exec_remote "echo \"[$(date "+%Y-%m-%d %H:%M:%S")] drivers check finished\" >> /home/user/provision-log.txt"
#
##rsync -avz --partial --info=progress2 --delete -e "ssh -p $TPORT" ./input/video1.mp4 $TUSER@$THOST:/home/$TUSER/face-blurer/input/
#
##exec_remote cd face-blurer \&\& \
##  docker run -v \$\(pwd\):/data linuxserver/ffmpeg -i "/data/input/video1.mp4" -fps_mode passthrough -q:v 0 -c:v png "/data/input/frame_%10d.png"
#
##exec_remote "cd face-blurer && rm -f output/sample*"
##exec_remote "cd face-blurer && docker run --rm --gpus all -v ./app:/app -v ./test-samples:/input:ro -v ./output:/output -v /tmp/blurer-cache/deepface:/root/.deepface -v /tmp/blurer-cache/root:/root/.cache blurer python blur_faces_retinaface.py"
#
#
#exec_remote "echo \"[$(date "+%Y-%m-%d %H:%M:%S")] finished\" >> /home/user/provision-log.txt"
