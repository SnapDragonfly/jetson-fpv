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
import screeninfo
import numpy as np

from collections import deque
from ultralytics import YOLO
from ultralytics.engine.results import Results
from jetson_utils import videoSource, videoOutput, Log, cudaToNumpy

# Define object detection and tracking interval
CONFIDENCE_THRESHOLD  = 0.5
TRACKING_INTERVAL     = 1

# Define font color as a parameter (e.g., white or yellow)
COLOR_WHITE   = (255, 255, 255)
COLOR_YELLOW  = (0, 255, 255)

FONT_SCALE     = 0.6
FONT_THICKNESS = 1
BOX_THICKNESS  = 1

FRAME_RATE_ESTIMATE_CNT = 60

# thread exit control:
exit_flag = threading.Event()

# window title
window_title = "YOLO Prediction"

# path for interpolate tracking method
paths        = []

def display_help():
    """
    Displays a formatted help message for the command-line arguments.
    """
    help_message = """
Usage: python yolo.py [options] <input> [output]

Description:
    View various types of video streams.

Positional arguments:
    input                URI of the input stream
    output               URI of the output stream (default: file://output_video.mp4)

Optional arguments:
    --no-headless        Enable the OpenGL GUI window (default: headless mode is enabled)
    --refresh-rate <int> Set the refresh_rate (default: 30)
    --confidence <float> Set YOLO confidence (default: 0.5)
    --model <str>        Set the model to use (default: 11n; options: 11n, 5nu, 8n, 8s)
    -h, --help           Show this help message and exit.

Examples:
    python yolo.py "file://input_video.mp4" "file://output_video.mp4"
    python yolo.py "rtsp://camera_stream" --no-headless --model 8n
"""
    print(help_message)

def handle_interrupt(signal_num, frame):
    print("yolo set exit_flag ... ...")
    exit_flag.set()

def predict_frame(frame_id, model, frame, class_indices):
    results = model.predict(source=frame, show=False, verbose=False, classes=class_indices, imgsz=[640, 640])
    return results

def capture_image(input):
    try:
        # Attempt to capture the next image
        img = input.Capture()

        # If capture is successful, return the image
        if img is not None:
            return img

    except Exception as e:
        # Catch any other exceptions and log them
        print(f"Unexpected error: {e}")
        
        # Optionally, break the loop or handle it differently
        return None  # Return None on error

def main():
    global window_title

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
        default="file://output_video.mkv",
        nargs='?',
        help="URI of the output stream (default: file://output_video.mkv)"
    )

    parser.add_argument(
        "--no-headless",
        action="store_false",
        dest="headless",
        help="Enable the OpenGL GUI window (default: headless mode is enabled)"
    )

    parser.add_argument(
        "--refresh-rate",
        type=int,
        default=60,
        dest="refresh_rate",
        help="Set the refresh_rate (default: 30)"
    )

    parser.add_argument(
        "--confidence",
        type=float,
        default=0.5,
        dest="confidence",
        help="Set YOLO confidence (default: 0.5)"
    )

    parser.add_argument(
        "--model",
        type=str,
        default="11n",
        dest="model",
        help="Set the model 11n(default)/5nu/8n"
    )

    try:
        args = parser.parse_known_args()[0]
    except:
        print("")
        parser.print_help()
        sys.exit(0)

    if args.headless:
        sys.argv.append("--headless")

    signal.signal(signal.SIGINT, handle_interrupt)

    # Load the YOLO model
    if args.model == "11n":
        model = YOLO('./model/yolo11n.engine')
    elif args.model == "5nu":
        model = YOLO('./model/yolov5nu.engine')
    elif args.model == "8n":
        model = YOLO('./model/yolov8n.engine')
    else:
        raise ValueError(f"Unsupported model: {args.model}. Please choose from 11n, 5nu, or 8n.")
        display_help()
        sys.exit(1)

    # Configurable list of target classes to detect
    class_names = model.names  # This is likely a dictionary {index: class_name}
    configurable_classes = [
        'person', 'car', 'motorcycle', 'bus', 'truck', 'airplane', 'boat'
    ]  # User-defined classes to detect

    # Convert class_names dict to list of class names and map them to indices
    class_indices = [index for index, name in class_names.items() if name in configurable_classes]

    print("Configured detection classes:", configurable_classes)
    print("Class indices for detection:", class_indices)

    # create video sources & outputs
    input = videoSource(args.input, argv=sys.argv)
    output = videoOutput(args.output, argv=sys.argv)

    # Initialize variables for Windows/FPS calculation
    previous_time      = time.time()
    first_frame_check  = True

    refresh_rate       = args.refresh_rate
    yolo_confidence    = args.confidence
    chk_inference_time = False
    max_inference_time    = 0
    latest_inference_time = 0

    # capture frames until EOS or user exits
    numFrames = 0
    results = []

    while True:
        # capture the next image
        img = capture_image(input)

        if img is None: # timeout
            if exit_flag.is_set():
                print("yolo timeout ready to exit ... ...")
                break
            continue  

        # Calculate max inference time
        current_time = time.time()
        elapsed_time = current_time - previous_time
        previous_time = current_time

        if first_frame_check:
            first_frame_check = False
            TRACKING_INTERVAL = max(1, round(input.GetFrameRate() / refresh_rate))

            # Get the current screen resolution
            screen = screeninfo.get_monitors()[0]  # Assuming the first monitor
            screen_width = screen.width
            screen_height = screen.height

            # Calculate the image dimensions
            img_width = img.width
            img_height = img.height
            
            # Check if the screen resolution is large enough for full screen
            if screen_width <= img_width and screen_height <= img_height:
                cv2.namedWindow(window_title, cv2.WND_PROP_FULLSCREEN)
                cv2.setWindowProperty(window_title, cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_FULLSCREEN)
                Log.Verbose(f"YOLO:  Full screen {screen_width} x {screen_height}, Interval {TRACKING_INTERVAL}")
            else:
                #cv2.namedWindow(window_title, cv2.WND_PROP_FULLSCREEN)
                #cv2.namedWindow(window_title, cv2.WND_PROP_NORMAL)
                cv2.namedWindow(window_title, cv2.WND_PROP_AUTOSIZE)

                # Calculate the center position if image size is smaller than the screen
                window_x = (screen_width - img_width) // 2
                window_y = (screen_height - img_height) // 2
                cv2.moveWindow(window_title, window_x, window_y)
                Log.Verbose(f"YOLO:  Image size ({img.width} x {img.height}, Interval {TRACKING_INTERVAL})")

        # Perform inference on the frame using YOLO
        cv2_frame = cudaToNumpy(img)

        if numFrames % FRAME_RATE_ESTIMATE_CNT == 0 or numFrames < 15:
            Log.Verbose(f"YOLO: captured {numFrames} frames ({img.width} x {img.height}) at {input.GetFrameRate():.1f}/{output.GetFrameRate():.1f} FPS")
            
            # Set the window title with the FPS value
            window_title = f"YOLO Prediction - {img.width:d}x{img.height:d} | {latest_inference_time:.3f}/{max_inference_time:.3f}"
            #cv2.setWindowTitle("YOLO Prediction", window_title)

        # Predict using Yolo algorithm
        if numFrames % TRACKING_INTERVAL == 0:
            results = predict_frame(numFrames, model, cv2_frame, class_indices)
            chk_inference_time = True
            if(TRACKING_INTERVAL == 1):
                latest_inference_time = elapsed_time
                if (latest_inference_time > max_inference_time and numFrames > 5):
                    max_inference_time = latest_inference_time
                    #Log.Verbose(f"YOLO {numFrames} - {img.width:d}x{img.height:d} | {latest_inference_time:.3f}/{max_inference_time:.3f}")
                #else:
                    #Log.Verbose(f"YOLO {numFrames} - {img.width:d}x{img.height:d} | {latest_inference_time:.3f}/{max_inference_time:.3f}")
        else:
            if chk_inference_time:
                chk_inference_time = False
                latest_inference_time = elapsed_time
                if (latest_inference_time > max_inference_time and numFrames > 5): 
                    max_inference_time = latest_inference_time
                    #Log.Verbose(f"YOLO {numFrames} - {img.width:d}x{img.height:d} | {latest_inference_time:.3f}/{max_inference_time:.3f}")
                #else:
                    #Log.Verbose(f"YOLO {numFrames} - {img.width:d}x{img.height:d} | {latest_inference_time:.3f}/{max_inference_time:.3f}")

        annotated_frame = cv2_frame.copy()
        if len(results) > 0 and hasattr(results[0], 'plot'):
            # loop over the detections
            for result in results[0].boxes.data.tolist():
                # extract the confidence (i.e., probability) associated with the prediction
                confidence = result[4]

                # filter out weak detections by ensuring the 
                # confidence is greater than the minimum confidence
                if float(confidence) < yolo_confidence:
                    continue

                # if the confidence is greater than the minimum confidence,
                # get the bounding box and the class id
                xmin, ymin, xmax, ymax = int(result[0]), int(result[1]), int(result[2]), int(result[3])
                class_id = int(result[5])
                class_name = results[0].names[class_id]

                #Log.Verbose(f"YOLO: {class_id} --> {xmin},{ymin},{xmax},{ymax} - {confidence}")

                # add the bounding box (x, y, w, h), confidence and class id to the results list
                # draw the bounding box and the track id
                cv2.rectangle(annotated_frame, (xmin, ymin), (xmax, ymax), COLOR_YELLOW, 2)

                if numFrames % TRACKING_INTERVAL == 0:
                    cv2.putText(annotated_frame, str(class_name), (xmin + 5, ymin - 8),cv2.FONT_HERSHEY_SIMPLEX, FONT_SCALE, COLOR_WHITE, FONT_THICKNESS)
                    #cv2.putText(annotated_frame, str(class_id), (xmin + 5, ymin - 8),cv2.FONT_HERSHEY_SIMPLEX, FONT_SCALE, COLOR_WHITE, FONT_THICKNESS)               
        
        # FPS text
        text_size = cv2.getTextSize(window_title, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)[0]
        text_x = img.width - text_size[0] - 10  # right
        text_y = 20  # to the top
        cv2.putText(annotated_frame, window_title, (text_x, text_y), cv2.FONT_HERSHEY_SIMPLEX, FONT_SCALE, COLOR_WHITE, FONT_THICKNESS)

        # Update the window title and display the frame with detections
        cv2.imshow("YOLO Prediction", annotated_frame)

        # render the image
        output.Render(img)
        
        # update the title bar
        output.SetStatus("Video Viewer | {:d}x{:d} | {:.1f} FPS".format(img.width, img.height, output.GetFrameRate()))

        numFrames += 1

        # exit on input/output EOS
        if not input.IsStreaming() or not output.IsStreaming():
            break

        if exit_flag.is_set():
            print("yolo video ready to exit ... ...")
            break

        # Exit the loop if the 'q' key is pressed
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cv2.destroyAllWindows()

if __name__ == "__main__":
    import sys
    if "--help" in sys.argv or "-h" in sys.argv:
        display_help()
        sys.exit(0)

    main()
    print("yolo done!")
    sys.exit(0)

