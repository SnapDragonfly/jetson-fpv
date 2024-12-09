# Install

1. install Jetpack/L4T version from nvidia: [link](https://docs.nvidia.com/jetson/archives/)
> Reference: 
>   - [Linux 36.3@Jetson Orin Nano之系统安装](https://blog.csdn.net/lida2003/article/details/139236880)
>   - [wfb-ng 开源代码之Jetson Orin安装](https://blog.csdn.net/lida2003/article/details/143145101)

2. install OpenCV with cuda support: [git link](https://github.com/SnapDragonfly/SnapLearnOpenCV/blob/main/scripts/install_opencv_for_jetson.sh)
3. install [jetson-utils](../module)
4. install [jetson-inference](../module)
5. install [wfb-ng](../module)
6. update [msposd](../module), and there is a binary version in [../utils/msposd](../utils/msposd)
7. install yolo: [git link](https://github.com/ultralytics/ultralytics)
> Reference: 
>   - [Linux 35.6 + JetPack v5.1.4@yolo安装](https://blog.csdn.net/lida2003/article/details/143618823)
>   - [Linux 35.6 + JetPack v5.1.4@python opencv安装](https://blog.csdn.net/lida2003/article/details/143814156)

8. install [DeepStream](../module)
> Reference: 
>   - [Linux 35.6 + JetPack v5.1.4@DeepStream安装](https://blog.csdn.net/lida2003/article/details/144195002)

9.  install [ByteTrack](../module)
```bash
$ sudo apt install libhdf5-dev
$ git clone https://github.com/NVIDIA-AI-IOT/torch2trt.git
$ cd torch2trt
$ sudo python3 setup.py install
$ python3 -c "from torch2trt import torch2trt; print('torch2trt installed successfully')"
```

*Note: Tested version is in the submodule if it's installed from source.*

# Tested version

```
Software part of jetson-stats 4.2.12 - (c) 2024, Raffaello Bonghi
Model: NVIDIA Orin Nano Developer Kit - Jetpack 5.1.4 [L4T 35.6.0]
NV Power Mode[0]: 15W
Serial Number: [XXX Show with: jetson_release -s XXX]
Hardware:
 - P-Number: p3767-0005
 - Module: NVIDIA Jetson Orin Nano (Developer kit)
Platform:
 - Distribution: Ubuntu 20.04 focal
 - Release: 5.10.216-tegra
jtop:
 - Version: 4.2.12
 - Service: Active
Libraries:
 - CUDA: 11.4.315
 - cuDNN: 8.6.0.166
 - TensorRT: 8.5.2.2
 - VPI: 2.4.8
 - OpenCV: 4.9.0 - with CUDA: YES
DeepStream C/C++ SDK version: 6.3

Python Environment:
Python 3.8.10
    GStreamer:                   YES (1.16.3)
  NVIDIA CUDA:                   YES (ver 11.4, CUFFT CUBLAS FAST_MATH)
        OpenCV version: 4.9.0  CUDA True
          YOLO version: 8.3.33
         Torch version: 2.1.0a0+41361538.nv23.06
   Torchvision version: 0.16.1+fdea156
DeepStream SDK version: 1.1.8
```
