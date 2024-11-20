# Install

1. install Jetpack/L4T version from nvidia: [link](https://docs.nvidia.com/jetson/archives/)
2. install OpenCV with cuda support: [git link](https://github.com/SnapDragonfly/SnapLearnOpenCV/blob/main/scripts/install_opencv_for_jetson.sh)
3. install [jetson-utils](module/jetson-utils)
4. install [jetson-inference](module/jetson-inference)
5. install [wfb-ng](module/wfb-ng)
6. install yolo: [git link](https://github.com/ultralytics/ultralytics)

*Note: Tested version is in the submodule if it's installed from source.*

# Tested version

- Jetpack 5.1.4 [L4T 35.6.0]
- OpenCV 4.9.0 [CUDA] (C++/python)
- Torch 2.1.0a0+41361538.nv23.06
- Torchvision 0.16.1+fdea156
- YOLO version 8.3.33