# YOLO

I believe YOLO should great picking up small object and do the analysis ASAP.

# Performance Tuning

- Step 1: According to [YOLO NVIDIA Guide](https://docs.ultralytics.com/guides/nvidia-jetson/)

```
$ yolo export model=yolo11n.pt format=engine  # creates 'yolo11n.engine'
```

- Step 2: 
  - [YOLO - Anyway to boost yolo performance on Jetson Orin?
#17640](https://github.com/ultralytics/ultralytics/issues/17640)
  - [NVIDIA - Anyway to boost yolo performance on Jetson Orin?](https://forums.developer.nvidia.com/t/anyway-to-boost-yolo-performance-on-jetson-orin/313795)

```
$ yolo export model=yolo11n.pt format=engine half=True
```

```
$ yolo export model=yolo11n.pt format=engine int8=True
```

*Note1: int8 improves a lot. So it's crucial to export model, adapting hardware acceleration.*

*Note2: Make sure maximize Jetson Orin's performance.*

```
$ sudo nvpmodel -m 0
$ sudo jetson_clocks
```

- Step 3: NVIDIA Jetson boards uses TensorRT, refer to [TensorRT Export for YOLOv8 Models](https://docs.ultralytics.com/integrations/tensorrt/) 

```
$ yolo export model=yolo11n.pt format="engine" batch=8 workspace=4 int8=True data="coco.yaml"
```

- Step 4: Improve model export according to [Model Export with Ultralytics YOLO](https://docs.ultralytics.com/modes/export/)

```
$ yolo export model=yolo11n.pt format="engine" batch=8 workspace=8 dynamic=True int8=True data="coco.yaml"
```

- Step 5: Add famous 11n/5nu/8n models
  - [Maximizing Deep Learning Performance on NVIDIA Jetson Orin with DLA](https://developer.nvidia.com/blog/maximizing-deep-learning-performance-on-nvidia-jetson-orin-with-dla/)
  - [ultralytics 8.3.21 NVIDIA DLA export support #16449](https://github.com/ultralytics/ultralytics/pull/16449)

```
$ yolo export model=yolo11n.pt format="engine" batch=8 workspace=2.0 imgsz=320 dynamic=True int8=True data="coco.yaml"
$ yolo export model=yolov5nu.pt format="engine" batch=8 workspace=2.0 imgsz=320 dynamic=True int8=True data="coco.yaml"
$ yolo export model=yolov8n.pt format="engine" batch=8 workspace=2.0 imgsz=320 dynamic=True int8=True data="coco.yaml"
```

*Note1: It's NOT good choice with `imgsz=1920,1080`, 640(default)/320 or 416(real time+GOOD accuracy)/256 or 128(embedded+NG accuracy).*

*Note2: `dynamic=False` improves speed, but input size will be different from image size on fpv requirements. Maybe more coding logical to handle larger sensor data coverage.*

*Note3: batch improves real time response, but need large resources. There is a balance between time delay/accuracy.*

- Step 6: Using YOLO's plot function increases speed

https://github.com/SnapDragonfly/jetson-fpv/blob/3aeebbbf479ecfdc9ba6883bf2b1a4a300861657/utils/yolo.py#L351-L354

- Step 7: [Boosting Inference FPS With Tracker Interpolated Detections](https://y-t-g.github.io/tutorials/yolo-tracker-interpolate/)

> stride=3 means that the detector would only be run on every 3rd frame. The other two frames would be interpolated using the Kalman filter predictions.

https://github.com/SnapDragonfly/jetson-fpv/blob/68d205311434012907e324a22828818150ef680f/utils/yolo.py#L110-L157

*Note: It's significantly speed up performance.*

# Ultralytics YOLO11 on NVIDIA Jetson using DeepStream SDK and TensorRT

- [Ultralytics YOLO11 on NVIDIA Jetson using DeepStream SDK and TensorRT](https://docs.ultralytics.com/guides/deepstream-nvidia-jetson/)

Firstly, clarify [Which DS version for Jetson Orin Nano/Jetpack 5.1.4/L4T 35.6.0?](https://forums.developer.nvidia.com/t/which-ds-version-for-jetson-orin-nano-jetpack-5-1-4-l4t-35-6-0/314452)

TBD. 

# ByteTrack: Multi-Object Tracking by Associating Every Detection Box

- [An Introduction to BYTETrack: Multi-Object Tracking by Associating Every Detection Box](https://www.datature.io/blog/introduction-to-bytetrack-multi-object-tracking-by-associating-every-detection-box)
- [ByteTrack: Multi-Object Tracking by Associating Every Detection Box](https://github.com/ifzhang/ByteTrack)

TBD.