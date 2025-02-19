# Jetpack 6.1 l4t36.4.0

```
$ sudo ./wrapper.sh help
[sudo] password for daniel:
Invalid module: help
Usage: ./wrapper.sh <module_name> {start|restart|ostart|orestart|stop|status|help|<other_command>} [additional_arguments]

Commands:
  start           Start a module
  restart         Restart a module
  ostart          Start a module without msposd
  orestart        Restart a module without msposd
  stop            Stop a module
  status          Check the status of a module
  help            Display this help message
  <other_command> Pass any other command directly to the module script, such as test etc.

Available modules
  Special modules: version wfb
     Base modules: viewer pyviewer gstreamer
 Extended modules: imagenet detectnet segnet posenet stabilizer yolo deepstream dsyolo dstrack

    Version Module: Check depended component versions.
        Wfb Module: Wifibroadcast transmission module.
     Viewer Module: Use video-viewer to handle video stream.
   pyViewer Module: Use python jetson_utils to handle video stream.
  GStreamer Module: GST pipelines to process audio and video, offering flexible, plugin-based support for playback, streaming, and media transformation.
   Imagenet Module: Image classification using Imagenet model.
  Detectnet Module: Object detection using DetectNet.
     Segnet Module: Image segmentation using SegNet.
    Posenet Module: Pose estimation using PoseNet.
 Stabilizer Module: Stabilizes the camera or system.
       Yolo Module: Real-time object detection using YOLO.
 Deepstream Module: Framework from NVIDIA that enables video analytics and AI processing, using hardware-accelerated inference for deep learning models in real-time.
 Deepstream + YOLO: DeepStream integrates YOLO for real-time object detection and tracking.
 Deepstream  Track: DeepStream with it's integrated tracking plugin.

$ sudo ./wrapper.sh version

Software part of jetson-stats 4.3.1 - (c) 2024, Raffaello Bonghi
Model: NVIDIA Jetson Orin Nano Developer Kit - Jetpack 6.1 [L4T 36.4.0]
NV Power Mode[0]: 15W
Serial Number: [XXX Show with: jetson_release -s XXX]
Hardware:
 - P-Number: p3767-0005
 - Module: NVIDIA Jetson Orin Nano (Developer kit)
Platform:
 - Distribution: Ubuntu 22.04 Jammy Jellyfish
 - Release: 5.15.148-tegra
jtop:
 - Version: 4.3.1
 - Service: Active
Libraries:
 - CUDA: 12.6.68
 - cuDNN: 9.3.0.75
 - TensorRT: 10.3.0.30
 - VPI: 3.2.4
 - OpenCV: 4.11.0 - with CUDA: YES

--------------------------------
NVIDIA SDK:
DeepStream C/C++ SDK version: 7.1
    jetson-inference version: c038530 (dirty)
        jetson-utils version: 6d5471c

--------------------------------
Python Environment:
Python 3.10.12
    GStreamer:                   YES (1.20.3)
  NVIDIA CUDA:                   YES (ver 12.6, CUFFT CUBLAS FAST_MATH)
         OpenCV version: 4.11.0  CUDA True
           YOLO version: 8.3.75
         PYCUDA version: 2024.1.2
          Torch version: 2.5.0a0+872d972e41.nv24.08
    Torchvision version: 0.20.0a0+afc54f7
 DeepStream SDK version: 1.2.0
onnxruntime     version: 1.20.1
onnxruntime-gpu version: 1.20.0

--------------------------------
FPV Environment:
jetson-fpv version: 4b34635 dirty
    WFB-ng version: 25.1.25.81795
    MSPOSD version: c28d645 20250218_184057
```

# Jetpack 5.1.4 l4t35.6

- [x] FPV features
    - [x] MSPOSD for ground station
    - [x] video-viewer
    - [ ] Adaptive wireless link
- [x] Jetson video analysis
    - [x] detectnet for object detection
    - [x] segnet for segmentation
    - [x] posenet for pose estimation
    - [x] imagenet for image recognition
- [x] yolo for object detection
- [ ] Real time video stabilizer
- [x] DeepStream analysis
    - [x] ByteTrack
    - [x] NvDCF tracker



```
$ sudo ./wrapper.sh help
Invalid module: help
Usage: ./wrapper.sh <module_name> {start|restart|ostart|orestart|stop|status|help|<other_command>} [additional_arguments]

Commands:
  start           Start a module
  restart         Restart a module
  ostart          Start a module without msposd
  orestart        Restart a module without msposd
  stop            Stop a module
  status          Check the status of a module
  help            Display this help message
  <other_command> Pass any other command directly to the module script, such as test etc.

Available modules
  Special modules: version wfb
     Base modules: viewer imagenet detectnet segnet posenet gstreamer
 Extended modules: stabilizer yolo deepstream dsyolo

    Version Module: Check depended component versions.
        Wfb Module: Wifibroadcast transmission module.
     Viewer Module: Displays the video stream.
   Imagenet Module: Image classification using Imagenet model.
  Detectnet Module: Object detection using DetectNet.
     Segnet Module: Image segmentation using SegNet.
    Posenet Module: Pose estimation using PoseNet.
  GStreamer Module: GST pipelines to process audio and video, offering flexible, plugin-based support for playback, streaming, and media transformation.
 Stabilizer Module: Stabilizes the camera or system.
       Yolo Module: Real-time object detection using YOLO.
 Deepstream Module: Framework from NVIDIA that enables video analytics and AI processing, using hardware-accelerated inference for deep learning models in real-time.
 Deepstream + YOLO: DeepStream integrates YOLO for real-time object detection and tracking.
```

## Tested Env4: CUDA 12.3.107 Torch 2.5.1+l4t35.6
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
 - CUDA: 12.3.107
 - cuDNN: 8.6.0.166
 - TensorRT: 8.5.2.2
 - VPI: 2.4.8
 - Vulkan: 1.3.204
 - OpenCV: 4.9.0 - with CUDA: YES
DeepStream C/C++ SDK version: 6.3

Python Environment:
Python 3.8.10
    GStreamer:                   YES (1.16.3)
  NVIDIA CUDA:                   YES (ver 11.4, CUFFT CUBLAS FAST_MATH)
         OpenCV version: 4.9.0  CUDA True
           YOLO version: 8.3.33
         PYCUDA version: 2024.1.2
          Torch version: 2.5.1+l4t35.6
    Torchvision version: 0.20.1a0+3ac97aa
 DeepStream SDK version: 1.1.8
onnxruntime     version: 1.16.3
onnxruntime-gpu version: 1.18.0
```

## Tested Env3: CUDA 11.8.89 Torch 2.5.1+l4t35.6
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
 - CUDA: 11.8.89
 - cuDNN: 8.6.0.166
 - TensorRT: 8.5.2.2
 - VPI: 2.4.8
 - Vulkan: 1.3.204
 - OpenCV: 4.9.0 - with CUDA: YES
DeepStream C/C++ SDK version: 6.3

Python Environment:
Python 3.8.10
    GStreamer:                   YES (1.16.3)
  NVIDIA CUDA:                   YES (ver 11.4, CUFFT CUBLAS FAST_MATH)
        OpenCV version: 4.9.0  CUDA True
          YOLO version: 8.3.33
         Torch version: 2.5.1+l4t35.6
   Torchvision version: 0.20.1a0+3ac97aa
DeepStream SDK version: 1.1.8
```

## Tested Env2: CUDA 11.4.315 Torch 2.4.1+l4t35.6
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
 - Vulkan: 1.3.204
 - OpenCV: 4.9.0 - with CUDA: YES
DeepStream C/C++ SDK version: 6.3

Python Environment:
Python 3.8.10
    GStreamer:                   YES (1.16.3)
  NVIDIA CUDA:                   YES (ver 11.4, CUFFT CUBLAS FAST_MATH)
        OpenCV version: 4.9.0  CUDA True
          YOLO version: 8.3.33
         Torch version: 2.4.1+l4t35.6
   Torchvision version: 0.19.1a0+6194369
DeepStream SDK version: 1.1.8
```

## Tested Env1: CUDA 11.4.315 Torch 2.1.0a0+41361538.nv23.06
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
