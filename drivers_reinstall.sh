#!/bin/bash
set -ex

. ./functions.sh

# Ensure script is run as root
if [[ "$EUID" -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

# Get the current NVIDIA driver version
nvidia-smi
NVIDIA_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader)
log_message "Current NVIDIA driver version: $NVIDIA_VERSION"

INFO_FILE="./input/metadata-drivers"
# save vars to local file
echo "NVIDIA_VERSION=$NVIDIA_VERSION" > $INFO_FILE
echo "STARTED=$(date +'%Y-%m-%d %H:%M:%S')" >> $INFO_FILE
log_message "Metadata saved to $INFO_FILE"

# Check if the driver version is 535.xxxx
if [[ $NVIDIA_VERSION == 535.* ]]; then
  log_message "Driver version is 535.xxxx. Proceeding with drivers update."
  echo "DRIVERS_NEED_UPDATE=1" >> $INFO_FILE
elif [[ $NVIDIA_VERSION == 550.* ]]; then
  log_message "Driver version is 550. That's OK."
  echo "DRIVERS_OK=1" >> $INFO_FILE
  exit 0
elif [[ $NVIDIA_VERSION == 545.* ]]; then
  log_message "Driver version is 545. That's OK."
  echo "DRIVERS_OK=1" >> $INFO_FILE
  exit 0
else
  echo "DRIVERS_ERROR=1" >> $INFO_FILE
  log_message "ERROR: Driver version is unknown."
  exit 1
fi

# Unhold NVIDIA packages if held
#apt-mark unhold $(dpkg --get-selections | grep hold | awk '{print $1}')
held_packages=$(dpkg --get-selections | grep hold | awk '{print $1}')
if [ -n "$held_packages" ]; then
  apt-mark unhold $held_packages
fi

# Remove old NVIDIA drivers and purge related packages
apt remove -y --purge '^nvidia-.*'

# Remove and re-add the graphics drivers PPA
add-apt-repository -y --remove ppa:graphics-drivers/ppa
add-apt-repository -y ppa:graphics-drivers/ppa

# Update package lists and install the new NVIDIA driver version
apt update
apt install -y nvidia-driver-545

# Install Docker GPU support
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Update package lists and install the NVIDIA container toolkit
apt-get update
apt-get install -y nvidia-container-toolkit

# Configure NVIDIA runtime for Docker
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker

echo "DRIVERS_UPDATED=1" >> $INFO_FILE
echo "FINISHED=$(date +'%Y-%m-%d %H:%M:%S')" >> $INFO_FILE

# Prompt user to reboot
log_message "----------------------------------------------------------"
log_message "System changes applied. Please reboot your system to complete the process."
log_message "----------------------------------------------------------"

##!/bin/bash
#
## run as root
#
## Get the NVIDIA driver version
#nvidia_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader)
#echo "Current NVIDIA driver version: $nvidia_version"
#
## Check if the version is 535
#if [[ $nvidia_version == 535.* ]]; then
#    echo "Driver version is 535.xxxx. Running drivers update"
#else
#    echo "Driver version is not 535. Current version: $nvidia_version"
#    exit 1
#fi
#
##dpkg --get-selections | grep hold
##apt-mark unhold libnvidia-cfg1-535
##apt-mark unhold libnvidia-compute-535
#apt-mark unhold $(dpkg --get-selections | grep hold | awk '{print $1}')
#
#apt remove -y --purge '^nvidia-.*'
#add-apt-repository -y --remove ppa:graphics-drivers/ppa
#add-apt-repository ppa:graphics-drivers/ppa
#apt update
#apt install -y nvidia-driver-545
#
## Docker with GPU support
#curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg   && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |     sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' |     tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
#apt-get update
#apt-get install -y nvidia-container-toolkit
#nvidia-ctk runtime configure --runtime=docker
#systemctl restart docker
#
#echo "----------------------------------------------------------"
#echo "You need to reboot the system to apply the changes"
#echo "----------------------------------------------------------"
