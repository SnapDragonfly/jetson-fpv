#!/bin/bash

cd scripts
source common/versions.sh
cd ..

echo
jetson_release

# Deepstream C/C++ SDK version
DEEPSTREAM_VERSION=$(get_deepstream_version)
echo "DeepStream C/C++ SDK version: $DEEPSTREAM_VERSION"
echo

CMD_NULL=" 2>/dev/null"
export DISPLAY=:0
echo "Python Environment:"

# Python version
eval "python3 --version" 

# OpenCV build information
eval "python3 -c \"import cv2; print(cv2.getBuildInformation())\" $CMD_NULL" | grep -E "CUDA|GStreamer" 

# OpenCV version and CUDA support
eval "python3 -c \"import cv2; print('         OpenCV version:', cv2.__version__, ' CUDA', cv2.cuda.getCudaEnabledDeviceCount() > 0)\" $CMD_NULL" | grep -v "EGL"

# YOLO version
YOLO_VERSION=$(eval yolo version $CMD_NULL | grep -v "EGL")
echo "           YOLO version: $YOLO_VERSION"

# pyCUDA version
PYCUDA_VERSION=$(eval "python -c \"import pycuda; print(pycuda.VERSION)\" | sed -E 's/^\(([^,]+), ([^,]+), ([^)]+)\)$/\1.\2.\3/'")
echo "         PYCUDA version: $PYCUDA_VERSION"

# PyTorch version
eval "python3 -c \"import torch; print('          Torch version:', torch.__version__)\" $CMD_NULL" | grep -v "EGL"

# Torchvision version
eval "python3 -c \"import torchvision; print('    Torchvision version:', torchvision.__version__)\" $CMD_NULL" | grep -v "EGL"

# Deepstream SDK version
eval "python3 -c \"import pyds; print(' DeepStream SDK version:', pyds.__version__)\" $CMD_NULL" | grep -v "EGL"

# ONNXRUNTIME version
eval "pip list $CMD_NULL" | grep onnxruntime | awk '{printf "%-15s version: %s\n", $1, $2}'

echo
echo "FPV Environment:"

echo "jetson-fpv Version: $(git rev-parse --short HEAD) $(git diff --quiet && echo '' || echo 'dirty')"
./utils/msposd/msposd --help | grep "Version" | sed 's/Version: \(.*\), compiled at: \(.*\)/    MSPOSD version: \1 \2/'
