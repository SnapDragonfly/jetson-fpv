#!/bin/bash

sudo apt-get install cmake libsoup2.4-dev libjson-glib-dev libgstrtspserver-1.0-dev
cd ../module/jetson-inference
git submodule update --init --recursive

./CMakePreBuild.sh

mkdir -p build
cd build

cmake ../
make

sudo make install
sudo ldconfig

cd ../../
