#!/usr/bin/env python3
#
# Copyright (c) 2019, NVIDIA CORPORATION. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.
#

import sys
import cv2
import time
import signal
import argparse
import threading

from ultralytics import YOLO
from jetson_utils import videoSource, videoOutput, Log, cudaToNumpy

# Define font color as a parameter (e.g., white or yellow)
FONT_COLOR = (255, 255, 255)  # White color
# FONT_COLOR = (0, 255, 255)  # Uncomment for yellow text

# thread exit control:
exit_flag = threading.Event()

def handle_interrupt(signal_num, frame):
    print("yolo set exit_flag ... ...")
    exit_flag.set()

def main():

    # parse command line
    parser = argparse.ArgumentParser(description="View various types of video streams", 
                                    formatter_class=argparse.RawTextHelpFormatter, 
                                    epilog=videoSource.Usage() + videoOutput.Usage() + Log.Usage())

    parser.add_argument(
        "input", 
        type=str, 
        help="URI of the input stream"
    )

    parser.add_argument(
        "output",
        type=str,
        default="file://output_video.mp4",
        nargs='?',
        help="URI of the output stream (default: file://output_video.mp4)"
    )

    parser.add_argument(
        "--no-headless",
        action="store_false",
        dest="headless",
        help="Enable the OpenGL GUI window (default: headless mode is enabled)"
    )

    args = parser.parse_known_args()[0]
    if args.headless:
        sys.argv.append("--headless")

    signal.signal(signal.SIGINT, handle_interrupt)

    # Load the YOLO model
    model = YOLO('./model/yolo11n.engine')

    # Configurable list of target classes to detect
    class_names = model.names  # This is likely a dictionary {index: class_name}
    configurable_classes = [
        'person', 'bicycle', 'car', 'motorcycle', 'bus', 'truck', 
        'fire hydrant', 'bench', 'bird', 'cat', 'dog', 'umbrella', 
        'handbag', 'suitcase', 'backpack', 'frisbee', 'skis', 'snowboard', 
        'sports ball', 'bottle', 'wine glass', 'cup', 'knife', 'chair', 
        'couch', 'potted plant', 'bed', 'dining table', 'tv', 'laptop', 
        'microwave', 'sink', 'refrigerator', 'vase', 'scissors', 'teddy bear'
    ]  # User-defined classes to detect

    # Convert class_names dict to list of class names and map them to indices
    class_indices = [index for index, name in class_names.items() if name in configurable_classes]

    print("Configured detection classes:", configurable_classes)
    print("Class indices for detection:", class_indices)


    # create video sources & outputs
    input = videoSource(args.input, argv=sys.argv)
    output = videoOutput(args.output, argv=sys.argv)

    # Initialize variables for Windows/FPS calculation
    previous_time = time.time()
    firt_frame_check = True

    # capture frames until EOS or user exits
    numFrames = 0

    while True:
        # capture the next image
        img = input.Capture()

        if img is None: # timeout
            if exit_flag.is_set():
                print("video stabilizer ready to exit ... ...")
                break
            continue  

        # Calculate FPS
        current_time = time.time()
        elapsed_time = current_time - previous_time
        fps = 1.0 / elapsed_time if elapsed_time > 0 else 0
        previous_time = current_time

        if firt_frame_check:
            firt_frame_check = False

            # Create a named window to avoid opening multiple windows
            cv2.namedWindow("YOLO Prediction", cv2.WINDOW_NORMAL)
            cv2.resizeWindow("YOLO Prediction", img.width, img.height)
            
        if numFrames % 25 == 0 or numFrames < 15:
            Log.Verbose(f"video-viewer:  captured {numFrames} frames ({img.width} x {img.height})")
            
            # Set the window title with the FPS value
            window_title = f"YOLO Prediction - {img.width:d}x{img.height:d} | FPS: {fps:.2f}"
            #window_title = "YOLO Prediction | {:d}x{:d} | {:.1f} FPS".format(img.width, img.height, input.GetFrameRate())
            cv2.setWindowTitle("YOLO Prediction", window_title)

        numFrames += 1

        # Perform inference on the frame using YOLO
        cv2_frame = cudaToNumpy(img)
        results = model.predict(source=cv2_frame, show=False)
        #results = model.predict(source=img, show=False)

        # Draw the bounding boxes on the image
        for result in results:  # Iterate over the results for each object detected
            boxes = result.boxes  # Detected boxes (each box corresponds to a detected object)
            for box in boxes:
                x1, y1, x2, y2 = box.xyxy[0]  # Get the coordinates of the bounding box
                confidence = box.conf[0]  # Confidence score for the detected object
                class_id = int(box.cls[0])  # Class ID of the detected object

                # Only process the boxes for the configured classes
                if class_id in class_indices:
                    label = f"{model.names[class_id]} {confidence:.2f}"  # Class name and confidence

                    # Draw the bounding box with a light color (e.g., light blue)
                    cv2.rectangle(cv2_frame, (int(x1), int(y1)), (int(x2), int(y2)), (173, 216, 230), 2)  # Light blue color

                    # Draw the label with a larger font and the chosen font color
                    cv2.putText(cv2_frame, label, (int(x1), int(y1)-10), cv2.FONT_HERSHEY_SIMPLEX, 1.0, FONT_COLOR, 2)  # Using FONT_COLOR

        # Update the window title and display the frame with detections
        cv2.imshow("YOLO Prediction", cv2_frame)

        # render the image
        output.Render(img)
        
        # update the title bar
        output.SetStatus("Video Viewer | {:d}x{:d} | {:.1f} FPS".format(img.width, img.height, output.GetFrameRate()))
        
        # exit on input/output EOS
        if not input.IsStreaming() or not output.IsStreaming():
            break

        if exit_flag.is_set():
            print("yolo ready to exit ... ...")
            break

        # Exit the loop if the 'q' key is pressed
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()
    print("yolo done!")
    sys.exit(0)

