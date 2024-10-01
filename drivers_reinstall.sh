#!/bin/bash

# run as root

#dpkg --get-selections | grep hold
#apt-mark unhold libnvidia-cfg1-535
#apt-mark unhold libnvidia-compute-535
apt-mark unhold $(dpkg --get-selections | grep hold | awk '{print $1}')

apt remove -y --purge '^nvidia-.*'
add-apt-repository -y --remove ppa:graphics-drivers/ppa
add-apt-repository ppa:graphics-drivers/ppa
apt update
apt install -y nvidia-driver-545

# Docker with GPU support
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg   && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |     sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' |     tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
apt-get update
apt-get install -y nvidia-container-toolkit
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker

echo "----------------------------------------------------------"
echo "You need to reboot the system to apply the changes"
echo "----------------------------------------------------------"
