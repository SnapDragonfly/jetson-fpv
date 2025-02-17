#!/bin/bash

sudo apt-get install -y mpv
sudo pip3 install ultralytics

cd ../model/
yolo export model=yolo11n.pt format=onnx
yolo export model=yolov5nu.pt format=onnx
yolo export model=yolov8n.pt format=onnx
yolo export model=yolo11n.pt format=engine int8=True
yolo export model=yolov5nu.pt format=engine int8=True
yolo export model=yolov8n.pt format=engine int8=True
cd -
