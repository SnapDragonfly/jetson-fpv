#!/bin/bash

# L4T 36.4.3/Jetpack 6.2(Jetson Orin Nano Super)
# L4T 36.4.0/Jetpack 6.1

echo "System update, upgrade dependencies."
sudo apt-get update

# https://forums.developer.nvidia.com/t/different-behavior-not-good-of-yolov11n-on-jetson-orin-nano-super/323968
#sudo apt-get upgrade -y --autoremove   

# install jtop for performance monitor
sudo apt install python3-pip -y
sudo pip3 install -U jetson-stats
sudo systemctl restart jtop.service

# install jetpack
sudo apt install nvidia-jetpack -y

# install basic tools
sudo apt-get install aptitude tree nano vim net-tools -y
sudo apt-get install cmake -y

# install for exit-key detection
sudo pip install keyboard screeninfo
