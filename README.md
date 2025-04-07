# jetson-fpv

Use Jetson as a ground station for FPV enthusiasts. 

Main features as follows:

- [x] Infrastructure
    - [x] wfb-ng
    - [x] Adaptive wireless link
- [x] FPV features
    - [x] MSPOSD for airunit/gs communication
    - [ ] pyosd for MAVLink
    - [ ] wfb-ng-osd for MAVLink
    - [x] video-viewer
    - [x] pyvideo-viewer
    - [x] pygstreamer
- [x] Jetson video analysis
    - [x] pysegnet for segmentation
    - [x] pyposenet for pose estimation
    - [ ] pyimagenet for image recognition (DS6.3 supported)
    - [ ] pydetectnet for object detection (DS6.3 supported)
- [ ] yolo for object detection (DS6.3 supported/[DS7.1 not accurate](https://github.com/ultralytics/ultralytics/issues/19134))
- [ ] Real time video stabilizer
- [x] DeepStream-app (DS6.3 H264 supported)
    - [x] DeepStream
    - [x] ByteTrack
    - [x] NvDCF tracker
- [x] DeepStream-python (DS7.1 H264/H265 supported)
    - [x] DeepStream
    - [ ] ByteTrack
    - [x] NvDCF tracker

*Note: Currently, it's focused on Jetpack 6.2 l4t36.4.3*

# Happy Flying!

Thanks to the community—especially [here](doc/THANKS.md)—where you'll find open-source code, hardware providers, and many other valuable resources. All these fun points serve as potential starting points for deepening the project.

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


