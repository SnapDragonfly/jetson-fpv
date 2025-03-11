#!/bin/bash

sudo apt install libcsfml-dev imagemagick -y

cd ../module/msposd
git submodule update --init --recursive

git apply ../../patch/msposd.*.patch

./build.sh native

cp -vf msposd ../../utils/msposd/
cp -vf fonts/*.png ../../utils/msposd/
cp -vf vtxmenu.ini ../../utils/msposd/

# Use latest ardupilot OSD
../../scripts/tools/convert_walksnail_to_sneakyfpv.sh ../ardupilot/libraries/AP_OSD/fonts/HDFonts/WS/
cp WS_APN_Europa_24_SneakyFPV.png ../../utils/msposd/font_ardu_hd.png
cp WS_APN_Europa_36_SneakyFPV.png ../../utils/msposd/font_ardu.png
