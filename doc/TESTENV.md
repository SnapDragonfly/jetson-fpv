# Tested Environment

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
