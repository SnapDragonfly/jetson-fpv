# jetson-fpv

Use Jetson as a ground station for FPV enthusiasts. 

Main features as follows:

- [x] Infrastructure
    - [x] wfb-ng
    - [ ] Adaptive wireless link
- [x] FPV features
    - [x] MSPOSD for ground station
    - [x] video-viewer
    - [x] pyvideo-viewer
    - [x] pygstreamer
- [x] Jetson video analysis
    - [x] pysegnet for segmentation
    - [x] pyposenet for pose estimation
    - [ ] pyimagenet for image recognition
    - [ ] pydetectnet for object detection
- [ ] yolo for object detection
- [ ] Real time video stabilizer
- [x] DeepStream-app (DS6.3 H264 supported)
    - [x] DeepStream
    - [x] ByteTrack
    - [x] NvDCF tracker
- [x] DeepStream-app (DS7.1 H264/H265 supported)
    - [x] DeepStream
    - [ ] ByteTrack
    - [x] NvDCF tracker

*Note: Currently, it's focused on Jetpack 6.2 l4t36.4.3*

# Happy Flying!

All these fun points serve as potential starting points for deepening the project.

- [Enjoy your flights, there is a few examples!](doc/EXAMPLE.md)

# Q & A

- [How to install the software?](doc/INSTALL.md)
- [How to use the software?](doc/MANUAL.md)
- [How to optimize YOLO performance?](doc/YOLO.md)
- [How to work with OpenIPC camera?](doc/OPENIPC.md)
- [What L4T/Jetpack versions are tested?](doc/TESTENV.md)
- [Is there any todo list?](doc/TODO.md)
- [Is there any reference for reading?](doc/REFERENCE.md)
- [History for jetson FPV](doc/HISTORY.md)

# Thanks to:

- [wfb-wifibroadcast@svpcom](https://github.com/svpcom/wfb-ng)
- [msposd@tipoman9](https://github.com/OpenIPC/msposd) for [betalight](https://betaflight.com/)/[inav](https://github.com/iNavFlight/inav)/[ardupilot](https://ardupilot.org/)
- [wfb-stabilizer@ejowerks](https://github.com/ejowerks/wfb-stabilizer)
- [wfb-stabilizer@tipoman9](https://github.com/tipoman9/wfb-stabilizer)
- [video-viewer@dusty-nv](https://github.com/dusty-nv/jetson-utils)
- [jetson-inference@dusty-nv](https://github.com/dusty-nv/jetson-inference)
- [jetson-yolo from nvidia](https://github.com/SnapDragonfly/jetson-yolo)
- [DeepStream-Yolo@marcoslucianops](https://github.com/marcoslucianops/DeepStream-Yolo)
- [deepstream_python_apps](https://github.com/NVIDIA-AI-IOT/deepstream_python_apps/tree/v1.1.8)
- [Ultralytics YOLO11](https://docs.ultralytics.com/)
- [OpenIPC for IP camera](https://openipc.org/)
- [ByteTrack, simple, fast and strong multi-object tracker](https://github.com/ifzhang/ByteTrack)
- [Adaptive-Link for OpenIPC FPV](https://github.com/sickgreg/OpenIPC-Adaptive-Link)
