#!/bin/bash

sudo apt install libyaml-cpp-dev

cd ../module/DeepStream-Yolo
git submodule update --init --recursive

export CUDA_VER=12.6
make -C nvdsinfer_custom_impl_Yolo clean && make -C nvdsinfer_custom_impl_Yolo

RELEASE_SO=nvdsinfer_custom_impl_Yolo/libnvdsinfer_custom_impl_Yolo.so
DEPLOY_PATH=../../utils/dsyolo/
cp -vf $RELEASE_SO $DEPLOY_PATH

cd -