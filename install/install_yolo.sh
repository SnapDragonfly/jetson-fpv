#!/bin/bash

sudo apt-get install -y mpv
sudo pip3 install ultralytics

cd ../model/
yolo export model=yolo11n.pt format=onnx
yolo export model=yolov5nu.pt format=onnx
yolo export model=yolov8n.pt format=onnx
yolo export model=yolo11n.pt format=engine
yolo export model=yolov5nu.pt format=engine
yolo export model=yolov8n.pt format=engine
cd -
