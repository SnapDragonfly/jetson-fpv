#!/bin/bash

# L4T 36.4.3/Jetpack 6.2/Jetson Orin Nano Super
echo "System update, upgrade dependencies."
sudo apt-get update
sudo apt-get dist-upgrade -y --autoremove   

# install jtop for performance monitor
sudo apt install python3-pip -y
sudo pip3 install -U jetson-stats
sudo systemctl restart jtop.service

# install jetpack
sudo apt install nvidia-jetpack -y

# install for exit-key detection
pip install keyboard screeninfo
