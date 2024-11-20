# jetson-fpv

Use Jetson as a ground station for FPV enthusiasts. 

Main features as follows:

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
- [x] Real time video stabilizer

# To Do

1. finish main features that planned to implement
2. extension commands for video-viewer/imagenet/detectnet/segnet/posenet
3. adaptive Open IPC link management
4. stabilizer doesn't seem to be that stabilized
5. optimize yolo performance
6. follow me Rover drive

# Happy Flying!

All these fun points serve as potential starting points for deepening the project.

# Q & A

- [How to install the software?](doc/INSTALL.md)
- [How to use the software?](doc/MANUAL.md)

# Thanks to:

- [wfb-wifibroadcast@svpcom](https://github.com/svpcom/wfb-ng)
- [msposd@tipoman9](https://github.com/OpenIPC/msposd) for [betalight](https://betaflight.com/)/[inav](https://github.com/iNavFlight/inav)/[ardupilot](https://ardupilot.org/)
- [wfb-stabilizer@ejowerks](https://github.com/ejowerks/wfb-stabilizer)
- [wfb-stabilizer@tipoman9](https://github.com/tipoman9/wfb-stabilizer)
- [video-viewer@dusty-nv](https://github.com/dusty-nv/jetson-utils)
- [jetson-inference@dusty-nv](https://github.com/dusty-nv/jetson-inference)
- [Ultralytics YOLO11](https://docs.ultralytics.com/)
- [OpenIPC for IP camera](https://openipc.org/)
