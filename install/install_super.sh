#!/bin/bash

# L4T 36.4.3/Jetpack 6.2/Jetson Orin Nano Super
# System update
sudo apt update
sudo apt-get upgrade -y

# install jtop for performance monitor
sudo apt install python3-pip
sudo pip3 install -U jetson-stats
sudo systemctl restart jtop.service

# install jetpack
sudo apt install nvidia-jetpack


