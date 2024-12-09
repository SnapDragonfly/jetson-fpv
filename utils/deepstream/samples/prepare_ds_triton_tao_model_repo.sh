#!/bin/bash
################################################################################
# SPDX-FileCopyrightText: Copyright (c) 2023 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: MIT
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.
################################################################################

# This script downloads NVIDIA TAO Toolkit pre-trained models available on NGC
# and converts them to TRT engine files for adding to Triton Inference Server
# model repository.
# If required the script downloads the tao-converter tool and installs it in
# $HOME/bin/tao-converter directory.
# While generating the models, batch size of 16 is used for dGPU and 1 for Jetson
# platforms.

set -e

TRITON_REPO_DIR="triton_tao_model_repo"
DOWNLOAD_DIR="/tmp/tao_models"

if [[ $(uname -m) == "aarch64" ]]; then
  TAO_CONVERTER_VERSION="v3.22.05_trt8.4_aarch64"
  BATCH_SIZE=1
  OPT_PROFILE_PEOPLENET_TRANSFORMER="inputs,1x3x544x960,1x3x544x960,1x3x544x960"
  OPT_PROFILE_PEOPLESEMSEGNET="input_2:0,1x3x544x960,1x3x544x960,1x3x544x960"
  OPT_PROFILE_FACENET="input_1,1x3x416x736,4x4x416x736,16x1x416x736"
  export TRT_LIB_PATH=/usr/lib/aarch64-linux-gnu
  export TRT_INC_PATH=/usr/include/aarch64-linux-gnu
else
  TAO_CONVERTER_VERSION="v4.0.0_trt8.5.1.7_x86"
  BATCH_SIZE=16
  OPT_PROFILE_PEOPLENET_TRANSFORMER="inputs,1x3x544x960,4x3x544x960,16x3x544x960"
  OPT_PROFILE_PEOPLESEMSEGNET="input_2:0,1x3x544x960,4x3x544x960,16x3x544x960"
  OPT_PROFILE_FACENET="input_1,1x3x416x736,4x4x416x736,16x1x416x736"
  export TRT_LIB_PATH="/usr/lib/x86_64-linux-gnu"
  export TRT_INC_PATH="/usr/include/x86_64-linux-gnu"
fi

if [ -z "$TAO_CONVERTER_BIN" ]; then

TAO_CONVERTER_DIR="$HOME/bin/tao-converter"
TAO_CONVERTER_BIN="$TAO_CONVERTER_DIR/tao-converter"

if [ ! -f "$TAO_CONVERTER_BIN" ]; then
  echo "Downloading and installing tao-converter utility into $TAO_CONVERTER_DIR"
  mkdir -p $TAO_CONVERTER_DIR
  wget --content-disposition https://api.ngc.nvidia.com/v2/resources/nvidia/tao/tao-converter/versions/$TAO_CONVERTER_VERSION/zip \
    -O $TAO_CONVERTER_DIR/tao-converter_${TAO_CONVERTER_VERSION}.zip
  unzip $TAO_CONVERTER_DIR/tao-converter_${TAO_CONVERTER_VERSION}.zip -d $TAO_CONVERTER_DIR
  chmod +x $TAO_CONVERTER_DIR/tao-converter
  rm -rf $TAO_CONVERTER_DIR/tao-converter_${TAO_CONVERTER_VERSION}.zip
fi

fi

echo "Using tao-converter utility from this location: $TAO_CONVERTER_BIN"
echo "Downloading PeopleNet Transformer model from NGC TAO repository"

MODEL_REPO_DIR=$TRITON_REPO_DIR/peoplenet_transformer
MODEL_DOWNLOAD_DIR=$DOWNLOAD_DIR/peoplenet_transformer

mkdir -p $MODEL_DOWNLOAD_DIR

wget https://api.ngc.nvidia.com/v2/models/nvidia/tao/peoplenet_transformer/versions/deployable_v1.0/files/resnet50_peoplenet_transformer.etlt \
    -O $MODEL_DOWNLOAD_DIR/resnet50_peoplenet_transformer.etlt
wget https://api.ngc.nvidia.com/v2/models/nvidia/tao/peoplenet_transformer/versions/deployable_v1.0/files/labels.txt \
    -O $MODEL_REPO_DIR/labels.txt
sed -i 's/\r$//' $MODEL_REPO_DIR/labels.txt

echo "Creating TensorRT engine file for PeopleNet Transformer"
echo "Setting batch size to $BATCH_SIZE"
CONFIG_FILE=$MODEL_REPO_DIR/config.pbtxt
sed -i -e "s|max_batch_size.*|max_batch_size: $BATCH_SIZE|" $CONFIG_FILE

mkdir -p $MODEL_REPO_DIR/1

$TAO_CONVERTER_BIN $MODEL_DOWNLOAD_DIR/resnet50_peoplenet_transformer.etlt \
              -k nvidia_tao \
              -d 3,544,960 \
              -p $OPT_PROFILE_PEOPLENET_TRANSFORMER \
              -o pred_boxes,pred_logits \
              -t fp16 \
              -m $BATCH_SIZE \
              -e $MODEL_REPO_DIR/1/model.plan

echo "Downloading PeopleSemSegNet Shuffle model from NGC TAO repository"

MODEL_REPO_DIR=$TRITON_REPO_DIR/peoplesemsegnet_shuffle
MODEL_DOWNLOAD_DIR=$DOWNLOAD_DIR/peoplesemsegnet_shuffle

mkdir -p $MODEL_DOWNLOAD_DIR

wget --content-disposition "https://api.ngc.nvidia.com/v2/models/nvidia/tao/peoplesemsegnet/versions/deployable_shuffleseg_unet_v1.0/zip" \
-O $MODEL_DOWNLOAD_DIR/deployable_shuffleseg_unet_v1.0.zip
unzip $MODEL_DOWNLOAD_DIR/deployable_shuffleseg_unet_v1.0.zip -d $MODEL_DOWNLOAD_DIR/
rm $MODEL_DOWNLOAD_DIR/deployable_shuffleseg_unet_v1.0.zip
cp $MODEL_DOWNLOAD_DIR/labels.txt $MODEL_REPO_DIR/

echo "Setting batch size to $BATCH_SIZE"
CONFIG_FILE=$MODEL_REPO_DIR/config.pbtxt
sed -i -e "s|max_batch_size.*|max_batch_size: $BATCH_SIZE|" $CONFIG_FILE

mkdir -p $MODEL_REPO_DIR/1

$TAO_CONVERTER_BIN $MODEL_DOWNLOAD_DIR/peoplesemsegnet_shuffleseg_etlt.etlt \
              -c $MODEL_DOWNLOAD_DIR/peoplesemsegnet_shuffleseg_cache.txt \
              -k tlt_encode \
              -p $OPT_PROFILE_PEOPLESEMSEGNET \
              -o argmax_1 \
              -t int8 \
              -m $BATCH_SIZE \
              -e $MODEL_REPO_DIR/1/model.plan

echo "Downloading FaceNet from NGC TAO repository"

MODEL_REPO_DIR=$TRITON_REPO_DIR/facenet
MODEL_DOWNLOAD_DIR=$DOWNLOAD_DIR/facenet

mkdir -p $MODEL_DOWNLOAD_DIR

wget https://api.ngc.nvidia.com/v2/models/nvidia/tao/facenet/versions/pruned_quantized_v2.0.1/files/model.etlt \
    -O $MODEL_DOWNLOAD_DIR/model.etlt
wget https://api.ngc.nvidia.com/v2/models/nvidia/tao/facenet/versions/pruned_quantized_v2.0.1/files/int8_calibration.txt \
    -O $MODEL_REPO_DIR/int8_calibration.txt

echo "Creating TensorRT engine file for FaceNet"
echo "Setting batch size to $BATCH_SIZE"
CONFIG_FILE=$MODEL_REPO_DIR/config.pbtxt
sed -i -e "s|max_batch_size.*|max_batch_size: $BATCH_SIZE|" $CONFIG_FILE

mkdir -p $MODEL_REPO_DIR/1

$TAO_CONVERTER_BIN $MODEL_DOWNLOAD_DIR/model.etlt \
              -c $MODEL_REPO_DIR/int8_calibration.txt \
              -k nvidia_tlt \
              -d 3,416,736 \
              -p $OPT_PROFILE_FACENET \
              -o output_bbox/BiasAdd,output_cov/Sigmoid \
              -t int8 \
              -m $BATCH_SIZE \
              -e $MODEL_REPO_DIR/1/model.plan

echo "Deleting the downloaded model files in $DOWNLOAD_DIR."
rm -rf $DOWNLOAD_DIR

echo "Model repository prepared successfully."
