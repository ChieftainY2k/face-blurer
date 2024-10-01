#!/bin/bash

set -ex

# Ensure script is run as root
if [[ "$EUID" -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

# Log start time
log_message() {
  local message="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message"
}

# Get the current NVIDIA driver version
nvidia-smi
nvidia_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader)
log_message "Current NVIDIA driver version: $nvidia_version"

# Check if the driver version is 535.xxxx
if [[ $nvidia_version == 535.* ]]; then
  log_message "Driver version is 535.xxxx. Proceeding with drivers update."
elif [[ $nvidia_version == 545.* ]]; then
  log_message "Driver version is 545. That's OK."
  exit 0
else
  log_message "ERROR: Driver version is unknown. don't know what do do."
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
