#!/bin/bash

cd ../module/ByteTrack/deploy/DeepStream/
mkdir -p build && cd build
cmake ..
make ByteTracker

RELEASE_SO=../lib/libByteTracker.so
DEPLOY_PATH=../../../../../utils/dsyolo/
cp -vf $RELEASE_SO $DEPLOY_PATH

cd -