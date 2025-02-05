

- [Ardupilot开源无人机之Geek SDK进展2024-2025](https://blog.csdn.net/lida2003/article/details/144977640)
- [Ardupilot开源无人机之Geek SDK讨论](https://blog.csdn.net/lida2003/article/details/144115659)



# 1. install Jetpack/L4T version from nvidia
> Reference: 
>   - [NVIDIA - Jetson Archives](https://docs.nvidia.com/jetson/archives/)
>   - [Linux 36.3@Jetson Orin Nano之系统安装](https://blog.csdn.net/lida2003/article/details/139236880)

# 2. install OpenCV with cuda support
> Reference: 
>   - [OpenCV with CUDA installation script](https://github.com/SnapDragonfly/SnapLearnOpenCV/blob/main/scripts/install_opencv_for_jetson.sh)
>   - [ubuntu22.04@Jetson Orin Nano之OpenCV安装](https://blog.csdn.net/lida2003/article/details/136197353)
>   - [Linux 35.6 + JetPack v5.1.4@python opencv安装](https://blog.csdn.net/lida2003/article/details/143814156)
>   - [ubuntu22.04@laptop OpenCV安装](https://blog.csdn.net/lida2003/article/details/136004884)

# 3. install [jetson-inference](../module)
> Reference: 
>   - [Linux 36.3 + JetPack v6.0@jetson-inference之示例安装](https://blog.csdn.net/lida2003/article/details/139357950)
>   - [Linux 36.3 + JetPack v6.0@jetson-inference之视频操作](https://blog.csdn.net/lida2003/article/details/139358559)
>   - [Linux 36.3 + JetPack v6.0@jetson-inference之图像分类](https://blog.csdn.net/lida2003/article/details/139364552)
>   - [Linux 36.3 + JetPack v6.0@jetson-inference之目标检测](https://blog.csdn.net/lida2003/article/details/139377486)
>   - [Linux 36.3 + JetPack v6.0@jetson-inference之语义分割](https://blog.csdn.net/lida2003/article/details/139378435)

# 4. install [jetson-utils](../module)
> Do as [jetson-utils](../module) say.

# 5. install [wfb-ng](../module)
> Reference: 
>   - [wfb-ng 开源代码之Jetson Orin安装](https://blog.csdn.net/lida2003/article/details/143145101)
>   - [wfb-ng 开源代码之Jetson Orin问题定位](https://blog.csdn.net/lida2003/article/details/144091735)
>   - [wfb-ng 开源代码之libsodium应用](https://blog.csdn.net/lida2003/article/details/144717865)
>   - [wfb-ng Release 23.01镜像无头烧录&配置(1)](https://blog.csdn.net/lida2003/article/details/129359378)
>   - [wfb-ng Release 23.01镜像无头烧录&配置(2)](https://blog.csdn.net/lida2003/article/details/129458288)
>   - [FPV Camera(RPI3+V2.1) | wfb-ng Release 23.01 | ubuntu20.04 gnome软解测试](https://blog.csdn.net/lida2003/article/details/129478119)
>   - [FPV Camera(RPI3+V2.1) | wfb-ng Release 23.01 | Ubuntu 20.04 xfce软解测试](https://blog.csdn.net/lida2003/article/details/129491517)
>   - [FPV Camera(RPI 3B+/Zero W+V2.1) | wfb-ng Release 23.01 | H264硬解测试](https://blog.csdn.net/lida2003/article/details/129623814)
>   - [wfb-ng 开源工程结构&代码框架简明介绍](https://blog.csdn.net/lida2003/article/details/129534129)
>   - [ubuntu22.04@laptop安装&配置wfb-ng](https://blog.csdn.net/lida2003/article/details/129581472)
>   - [wfb-ng 开源代码之wfb_tx&wfb_rx](https://blog.csdn.net/lida2003/article/details/141813745)
>   - [wfb-ng 开源代码之wfb_tx模式更新](https://blog.csdn.net/lida2003/article/details/142514027)
>   - [wfb-ng 开源代码之树莓派3B+ Bookworm安装](https://blog.csdn.net/lida2003/article/details/144726793)
>   - [wfb-ng 开源代码之树莓派3B+ Bookworm无线配置](https://blog.csdn.net/lida2003/article/details/144856822)

# 6. install pytorch/pycuda
> Reference: 
>   - [NVIDIA - PyTorch for Jetson](https://forums.developer.nvidia.com/t/pytorch-for-jetson/72048)
>   - [Linux 35.6 + JetPack v5.1.4之 pytorch编译](https://blog.csdn.net/lida2003/article/details/144800701)
>   - [Linux 35.6 + JetPack v5.1.4之 pytorch升级](https://blog.csdn.net/lida2003/article/details/144965814)
>   - [Jetson Orin Nano Super之pytorch + torchvision安装](https://blog.csdn.net/lida2003/article/details/145322174)
>   - [Linux 35.6 + JetPack v5.1.4之 pyCUDA升级](https://blog.csdn.net/lida2003/article/details/145184322)

# 7. install yolo: [git link](https://github.com/ultralytics/ultralytics)
> Reference: 
>   - [Linux 35.6 + JetPack v5.1.4@yolo安装](https://blog.csdn.net/lida2003/article/details/143618823)

# 8. install [DeepStream](../module)
> Reference: 
>   - [Linux 35.6 + JetPack v5.1.4@DeepStream安装](https://blog.csdn.net/lida2003/article/details/144195002)

# 9. install [onnxruntime](../module)

# 10.1 install [msposd](../module), and there is a binary version in [../utils/msposd](../utils/msposd)
> Has compiled, if there is any exception, do as [jetson-utils](../module) say.

# 10.2 install [jetson-yolo](../module)

# 10.3 install [DeepStream-Yolo](../module)

# 10.4 install [ByteTrack](../module)
```bash
$ sudo apt install libhdf5-dev
$ git clone https://github.com/NVIDIA-AI-IOT/torch2trt.git
$ cd torch2trt
$ sudo python3 setup.py install
$ python3 -c "from torch2trt import torch2trt; print('torch2trt installed successfully')"
```

# 11.  install [OpenIPC adaptive link](https://github.com/SnapDragonfly/OpenIPC-Adaptive-Link/tree/arrange_project_structure)
> Reference: 
>   - [OpenIPC开源FPV之Adaptive-Link工程解析](https://blog.csdn.net/lida2003/article/details/144498046)
>   - [OpenIPC开源FPV之Adaptive-Link天空端代码解析](https://blog.csdn.net/lida2003/article/details/144501405)
>   - [OpenIPC开源FPV之Adaptive-Link地面站代码解析](https://blog.csdn.net/lida2003/article/details/144515266)

*Note: Tested version is in the submodule if it's installed from source.*