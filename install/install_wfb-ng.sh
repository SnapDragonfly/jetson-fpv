#!/bin/bash

sudo rm -f /etc/default/wifibroadcast
sudo rm -f /etc/wifibroadcast.cfg

cd ../module/wfb-ng
git submodule update --init --recursive

sudo ./scripts/install_gs.sh

cd ../../
