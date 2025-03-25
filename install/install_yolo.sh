#!/bin/bash

sudo apt-get install -y mpv
sudo pip3 install ultralytics

cd ../model/

#yolo export model=yolo11n.pt format=onnx
#yolo export model=yolov5nu.pt format=onnx
#yolo export model=yolov8n.pt format=onnx

# YOLO FP32 imgsz=640
#yolo export model=yolo11n.pt format=engine
#yolo export model=yolov5nu.pt format=engine
#yolo export model=yolov8n.pt format=engine

# YOLO FP16 imgsz=320
#yolo export model=yolo11n.pt format=engine imgsz=320 half=True
#yolo export model=yolov5nu.pt format=engine imgsz=320 half=True
#yolo export model=yolov8n.pt format=engine imgsz=320 half=True

# YOLO INT8
yolo export model=yolo11n.pt format=engine workspace=4 int8=True data=coco.yaml
yolo export model=yolov5nu.pt format=engine workspace=4 int8=True data=coco.yaml
yolo export model=yolov8n.pt format=engine workspace=4 int8=True data=coco.yaml
cd -
