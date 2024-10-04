#!/bin/bash
set -euo pipefail

. ./functions.sh

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

INFO_FILE="./input/metadata-provision"

# Inject SSH keys
echo "Injecting keys..."
ssh "$TUSER@$THOST" -p "$TPORT" 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
cat ~/.ssh/id_rsa.pub | ssh "$TUSER@$THOST" -p "$TPORT" 'cat >> ~/.ssh/authorized_keys'
echo "Keys injected."

log_message "started"
exec_remote "cd face-blurer && echo \"STARTED=$(date +'%Y-%m-%d %H:%M:%S')\" > ${INFO_FILE}"

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
exec_remote "cd face-blurer && git checkout metadata4"
log_message "repo clone finished"

# Run driver check script
log_message "drivers check started"
exec_remote "cd face-blurer && sudo ./drivers_reinstall.sh"
log_message "drivers check finished"

log_message "rebooting server..."
#exec_remote "sudo reboot"
exec_remote "sudo bash -c \"sleep 3 && sudo reboot\" &"
log_message "waiting..."
countdown_seconds 10
# wait until server is reabooted, check every 1 second
while ! exec_remote "uptime"; do
  #  echo -n "."
  log_message "still waiting..."
  countdown_seconds 3
done
countdown_seconds 20
log_message "server is up"
exec_remote nvidia-smi

# Build Docker image
log_message "docker image build starting"
exec_remote "cd face-blurer && docker build -f Dockerfile.gpu --progress=plain . -t blurer"
log_message "docker image build finished"

exec_remote "cd face-blurer && echo \"FINISHED=$(date +'%Y-%m-%d %H:%M:%S')\" > ${INFO_FILE}"

# Uncomment if needed for rsync and Docker execution
# rsync -avz --partial --info=progress2 --delete -e "ssh -p $TPORT" ./input/video1.mp4 $TUSER@$THOST:/home/$TUSER/face-blurer/input/
# exec_remote "cd face-blurer && docker run -v \$(pwd):/data linuxserver/ffmpeg -i \"/data/input/video1.mp4\" -fps_mode passthrough -q:v 0 -c:v png \"/data/input/frame_%10d.png\""
# exec_remote "cd face-blurer && rm -f output/sample*"
# exec_remote "cd face-blurer && docker run --rm --gpus all -v ./app:/app -v ./test-samples:/input:ro -v ./output:/output -v /tmp/blurer-cache/deepface:/root/.deepface -v /tmp/blurer-cache/root:/root/.cache blurer python blur_faces_retinaface.py"

log_message "provisioning finished"
