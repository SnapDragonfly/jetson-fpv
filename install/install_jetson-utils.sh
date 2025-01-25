#!/bin/bash

cd ../module/jetson-utils
git submodule update --init --recursive

mkdir -p build
cd build

cmake ../
make -j$(nproc)

sudo make install
sudo ldconfig

cd ../../