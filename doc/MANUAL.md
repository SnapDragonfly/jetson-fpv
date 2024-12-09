# Manual

- Jetpack 5.1.4 [L4T 35.6.0]
- OpenCV 4.9.0 [CUDA] (C++/python)
- Torch 2.1.0a0+41361538.nv23.06
- Torchvision 0.16.1+fdea156
- YOLO version 8.3.33
- DeepStream C/C++(6.3) Python(1.1.8)

```
$ sudo ./wrapper.sh help
Invalid module: help
Usage: ./wrapper.sh <module_name> {start|stop|status|restart|help|<other_command>} [additional_arguments]

Commands:
  start           Start a module
  stop            Stop a module
  status          Check the status of a module
  restart         Restart a module
  help            Display this help message
  <other_command> Pass any other command directly to the module script

Available modules
     Base modules: wfb viewer imagenet detectnet segnet posenet gstreamer
 Extended modules: stabilizer yolo deepstream

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

# simple fpv

- start fpv
```
$ sudo ./wrapper.sh viewer start
```

- stop fpv
```
$ sudo ./wrapper.sh viewer stop
```

- check status
```
$ sudo ./wrapper.sh viewer status
```

# quit fpv

ESC Key to quit and get control back!

