#!/bin/bash

sudo apt install libcsfml-dev

cd ../module/msposd
git submodule update --init --recursive

./build.sh native

cp -vf msposd ../../utils/msposd/
cp -vf fonts/*.png ../../utils/msposd/
cp -vf vtxmenu.ini ../../utils/msposd/

