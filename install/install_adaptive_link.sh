#!/bin/bash

cd ../module/OpenIPC-Adaptive-Link/

git apply ../../patch/openipc-adaptive-link.*.patch

sudo chmod +x alink_gs
sudo chmod +x alink_install.sh
sudo ./alink_install.sh gs install



