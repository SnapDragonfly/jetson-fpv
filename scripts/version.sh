#!/bin/bash

echo
jetson_release
# Deepstream C/C++ SDK version
DEEPSTREAM_VERSION_FILE="/opt/nvidia/deepstream/deepstream/version"
if [[ -f "$DEEPSTREAM_VERSION_FILE" ]]; then
    DEEPSTREAM_VERSION=$(cat "$DEEPSTREAM_VERSION_FILE" | grep -oP '(?<=Version: ).*')
    echo "DeepStream C/C++ SDK version: $DEEPSTREAM_VERSION"
else
    echo "DeepStream C/C++ SDK version file not found"
fi
echo

CMD_NULL=" 2>/dev/null"
export DISPLAY=:0
echo "Python Environment:"

# Python version
eval "python3 --version" 

# OpenCV build information
eval "python3 -c \"import cv2; print(cv2.getBuildInformation())\" $CMD_NULL" | grep -E "CUDA|GStreamer" 

# OpenCV version and CUDA support
eval "python3 -c \"import cv2; print('        OpenCV version:', cv2.__version__, ' CUDA', cv2.cuda.getCudaEnabledDeviceCount() > 0)\" $CMD_NULL" | grep -v "EGL"

# YOLO version
YOLO_VERSION=$(eval yolo version $CMD_NULL | grep -v "EGL")
echo "          YOLO version: $YOLO_VERSION"

# PyTorch version
eval "python3 -c \"import torch; print('         Torch version:', torch.__version__)\" $CMD_NULL" | grep -v "EGL"

# Torchvision version
eval "python3 -c \"import torchvision; print('   Torchvision version:', torchvision.__version__)\" $CMD_NULL" | grep -v "EGL"

# Deepstream SDK version
eval "python3 -c \"import pyds; print('DeepStream SDK version:', pyds.__version__)\" $CMD_NULL" | grep -v "EGL"
