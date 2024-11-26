# Install

1. install Jetpack/L4T version from nvidia: [link](https://docs.nvidia.com/jetson/archives/)
2. install OpenCV with cuda support: [git link](https://github.com/SnapDragonfly/SnapLearnOpenCV/blob/main/scripts/install_opencv_for_jetson.sh)
3. install [jetson-utils](../module)
4. install [jetson-inference](../module)
5. install [wfb-ng](../module)
6. update [msposd](../module), and there is a binary version in [../utils/msposd](../utils/msposd)
7. install yolo: [git link](https://github.com/ultralytics/ultralytics)

*Note: Tested version is in the submodule if it's installed from source.*

# Tested version

- Jetpack 5.1.4 [L4T 35.6.0]
- OpenCV 4.9.0 [CUDA] (C++/python)
- Torch 2.1.0a0+41361538.nv23.06
- Torchvision 0.16.1+fdea156
- YOLO version 8.3.33

# Reference

- [wfb-ng 开源代码之Jetson Orin安装](https://blog.csdn.net/lida2003/article/details/143145101)
- [Linux 35.6 + JetPack v5.1.4@yolo安装](https://blog.csdn.net/lida2003/article/details/143618823)
- [Linux 35.6 + JetPack v5.1.4@python opencv安装](https://blog.csdn.net/lida2003/article/details/143814156)
