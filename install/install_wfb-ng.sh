#!/bin/bash

sudo apt-get purge -y wfb-ng

# Make sure all configuration is removed.
sudo rm -f /etc/default/wifibroadcast
sudo rm -f /etc/wifibroadcast.cfg
sudo rm -f /etc/gs.key
sudo rm -rf /usr/lib/python3/dist-packages/wfb_ng

cd ../module/wfb-ng
git submodule update --init --recursive

sudo ./scripts/install_gs.sh

# It should work with auto-detected wfb wifi card
# Just keep it for debug
#nics="$(wfb-nics)"
#echo "Using wifi autodetection WFB_NICS=\"$nics\""
#sudo sh -c "echo 'WFB_NICS=\"$nics\"' > /etc/default/wifibroadcast"

cd ../../
