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
- [ ] Real time video stabilizer
- [ ] DeepStream analysis
- [ ] ByteTrack

# To Do

1. finish main features that planned to implement
2. ~~extension commands for video-viewer/imagenet/detectnet/segnet/posenet~~
3. adaptive Open IPC link management
4. stabilizer doesn't seem to be that stabilized
5. ~~optimize yolo performance~~
6. follow me Rover drive
7. ~~add Ultralytics YOLO11 on NVIDIA Jetson using DeepStream SDK and TensorRT~~
8. add DeepStream analysis
9. add ByteTrack analysis

# Happy Flying!

All these fun points serve as potential starting points for deepening the project.

- [Enjoy your flights, there is a few examples!](doc/EXAMPLE.md)

# Q & A

- [How to install the software?](doc/INSTALL.md)
- [How to use the software?](doc/MANUAL.md)
- [How to optimize YOLO performance?](doc/YOLO.md)
- [How to work with OpenIPC camera?](doc/OPENIPC.md)

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
